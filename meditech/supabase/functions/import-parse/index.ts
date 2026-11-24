
import { createClient } from "@supabase/supabase-js";
import * as XLSX from "xlsx";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const MAX_FILE_SIZE = 2 * 1024 * 1024;
const MAX_ROWS = 1000;
const INSERT_CHUNK_SIZE = 200;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

type ImportRow = {
  source_row_number: number;
  raw_data: Record<string, unknown>;
  medicine_label: string;
  stock_quantity: number | null;
  price_per_unit: number | null;
  low_stock_threshold: number | null;
  nearest_expiry: string | null;
  matched_medicine_id: string | null;
  errors: string[];
  warnings: string[];
};

type CatalogueMedicine = {
  id: string;
  brand_name: string;
  strength: string;
};

function jsonReply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalize(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function normalizeHeader(value: unknown): string {
  return normalize(value);
}

function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let insideQuotes = false;

  const input = text.replace(/^\uFEFF/, "");

  for (let i = 0; i < input.length; i++) {
    const char = input[i];

    if (char === '"') {
      if (insideQuotes && input[i + 1] === '"') {
        cell += '"';
        i++;
      } else {
        insideQuotes = !insideQuotes;
      }
      continue;
    }

    if (char === "," && !insideQuotes) {
      row.push(cell);
      cell = "";
      continue;
    }

    if ((char === "\n" || char === "\r") && !insideQuotes) {
      if (char === "\r" && input[i + 1] === "\n") i++;

      row.push(cell);
      cell = "";

      if (row.some((value) => value.trim() !== "")) {
        rows.push(row);
      }

      row = [];
      continue;
    }

    cell += char;
  }

  if (insideQuotes) {
    throw new Error("The CSV file contains an unclosed quotation mark.");
  }

  row.push(cell);

  if (row.some((value) => value.trim() !== "")) {
    rows.push(row);
  }

  return rows;
}

function parseInteger(value: unknown): number | null {
  const text = String(value ?? "").trim();

  if (text === "") return null;
  if (!/^-?\d+$/.test(text)) return null;

  const parsed = Number(text);

  if (!Number.isSafeInteger(parsed)) return null;
  if (parsed < -2147483648 || parsed > 2147483647) return null;

  return parsed;
}

function parsePrice(value: unknown): number | null {
  const text = String(value ?? "").trim();

  if (text === "") return null;
  if (!/^-?\d+(\.\d{1,2})?$/.test(text)) return null;

  const parsed = Number(text);

  if (!Number.isFinite(parsed)) return null;
  if (Math.abs(parsed) > 9999999999.99) return null;

  return parsed;
}

function parseExpiry(value: unknown): string | null {
  let text = "";

  if (typeof value === "number" && Number.isFinite(value)) {
    // Excel stores dates as serial numbers (days since 1899-12-30).
    const utcMs = Math.round((value - 25569) * 86400 * 1000);
    const d = new Date(utcMs);
    if (Number.isNaN(d.getTime())) return null;
    text = [
      String(d.getUTCFullYear()).padStart(4, "0"),
      String(d.getUTCMonth() + 1).padStart(2, "0"),
      String(d.getUTCDate()).padStart(2, "0"),
    ].join("-");
  } else if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return null;

    text = [
      String(value.getFullYear()).padStart(4, "0"),
      String(value.getMonth() + 1).padStart(2, "0"),
      String(value.getDate()).padStart(2, "0"),
    ].join("-");
  } else {
    text = String(value ?? "").trim();
  }

  if (text === "") return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return null;

  const date = new Date(`${text}T00:00:00Z`);

  if (
    Number.isNaN(date.getTime()) ||
    date.toISOString().slice(0, 10) !== text
  ) {
    return null;
  }

  return text;
}

function makeMedicineKey(brandName: string, strength: string): string {
  return normalize(`${brandName} ${strength}`);
}

function classifyHeader(raw: unknown): string {
  const h = normalizeHeader(raw).replace(/[_\-]+/g, " ");
  if (h.includes("medicine") || h.includes("brand")) return "medicine";
  if (h.includes("low") || h.includes("threshold")) return "threshold";
  if (h.includes("stock") || h.includes("qty") || h.includes("quantity")) return "stock";
  if (h.includes("price") || h.includes("cost")) return "price";
  if (h.includes("expiry") || h.includes("expiration") || h.includes("date")) return "expiry";
  return "";
}

function isHeaderLikeRow(cells: unknown[]): boolean {
  const classified = new Set(cells.map(classifyHeader));
  return classified.has("medicine") && classified.has("stock") && classified.has("price");
}

function parseRows(
  sourceRows: unknown[][],
  catalogue: CatalogueMedicine[],
): ImportRow[] {
  if (sourceRows.length < 2) {
    throw new Error("The file has a header but no data rows.");
  }

  const headerTypes = sourceRows[0].map(classifyHeader);

  const headerIndexes = {
    medicine: headerTypes.indexOf("medicine"),
    stock: headerTypes.indexOf("stock"),
    price: headerTypes.indexOf("price"),
    threshold: headerTypes.indexOf("threshold"),
    expiry: headerTypes.indexOf("expiry"),
  };

  if (headerIndexes.medicine < 0) {
    throw new Error("Missing required column: medicine (brand and strength)");
  }
  if (headerIndexes.stock < 0) {
    throw new Error("Missing required column: stock_quantity");
  }
  if (headerIndexes.price < 0) {
    throw new Error("Missing required column: price_per_unit");
  }

  const headers = sourceRows[0].map(normalizeHeader);

  const catalogueByLabel = new Map<string, string[]>();

  for (const medicine of catalogue) {
    const key = makeMedicineKey(
      medicine.brand_name,
      medicine.strength,
    );

    const existing = catalogueByLabel.get(key) ?? [];
    existing.push(medicine.id);
    catalogueByLabel.set(key, existing);
  }

  const dataRows = sourceRows.slice(1).filter((r) => !isHeaderLikeRow(r));

  if (dataRows.length > MAX_ROWS) {
    throw new Error(`The file exceeds the ${MAX_ROWS}-row limit.`);
  }

  const parsedRows: ImportRow[] = dataRows.map((cells, index) => {
    const medicineLabel = String(
      cells[headerIndexes.medicine] ?? "",
    ).trim();

    const stockRaw = cells[headerIndexes.stock] ?? "";
    const priceRaw = cells[headerIndexes.price] ?? "";

    const thresholdRaw = headerIndexes.threshold >= 0
      ? cells[headerIndexes.threshold] ?? ""
      : "";

    const expiryRaw = headerIndexes.expiry >= 0
      ? cells[headerIndexes.expiry] ?? ""
      : "";

    const stockText = String(stockRaw).trim();
    const priceText = String(priceRaw).trim();
    const thresholdText = String(thresholdRaw).trim();
    const expiryText = String(expiryRaw).trim();

    const stock = parseInteger(stockRaw);
    const price = parsePrice(priceRaw);
    const threshold = thresholdText === ""
      ? null
      : parseInteger(thresholdRaw);
    const expiry = expiryText === ""
      ? null
      : parseExpiry(expiryRaw);

    const errors: string[] = [];

    if (!medicineLabel) {
      errors.push("Medicine is required.");
    }

    if (stockText === "") {
      errors.push("Stock quantity is required.");
    } else if (stock === null) {
      errors.push("Stock quantity must be a whole number.");
    } else if (stock < 0) {
      errors.push("Stock quantity cannot be negative.");
    }

    if (priceText === "") {
      errors.push("Price per unit is required.");
    } else if (price === null) {
      errors.push("Price must be a valid amount with up to 2 decimal places.");
    } else if (price <= 0) {
      errors.push("Price per unit must be greater than zero.");
    }

    if (thresholdText !== "") {
      if (threshold === null) {
        errors.push("Low-stock threshold must be a whole number.");
      } else if (threshold < 1) {
        errors.push("Low-stock threshold must be at least 1.");
      }
    }

    if (expiryText !== "" && expiry === null) {
      errors.push("Nearest expiry date must use YYYY-MM-DD.");
    }

    const medicineMatches =
      catalogueByLabel.get(normalize(medicineLabel)) ?? [];

    let matchedMedicineId: string | null = null;

    if (medicineLabel !== "") {
      if (medicineMatches.length === 0) {
        errors.push("Medicine was not found in the active catalogue.");
      } else if (medicineMatches.length > 1) {
        errors.push("Medicine label matches multiple catalogue entries.");
      } else {
        matchedMedicineId = medicineMatches[0];
      }
    }

    const rawData: Record<string, unknown> = {};

    headers.forEach((header, columnIndex) => {
      rawData[header || `column_${columnIndex + 1}`] =
        cells[columnIndex] ?? "";
    });

    return {
      source_row_number: index + 2,
      raw_data: rawData,
      medicine_label: medicineLabel,
      stock_quantity: stock,
      price_per_unit: price,
      low_stock_threshold: threshold,
      nearest_expiry: expiry,
      matched_medicine_id: matchedMedicineId,
      errors,
      warnings: [],
    };
  });

  const seenMedicineIds = new Set<string>();

  for (const row of parsedRows) {
    if (!row.matched_medicine_id) continue;

    if (seenMedicineIds.has(row.matched_medicine_id)) {
      row.errors.push("This medicine appears more than once in the import.");
    } else {
      seenMedicineIds.add(row.matched_medicine_id);
    }
  }

  return parsedRows;
}

function createTemplate(): Response {
  const worksheet = XLSX.utils.aoa_to_sheet([
    [
      "Medicine (brand and strength)",
      "Stock quantity",
      "Price per unit",
      "Low-stock threshold",
      "Nearest expiry date",
    ],
  ]);

  worksheet["!cols"] = [
    { wch: 36 },
    { wch: 18 },
    { wch: 18 },
    { wch: 22 },
    { wch: 22 },
  ];

  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, "Inventory Import");

  const output = XLSX.write(workbook, {
    bookType: "xlsx",
    type: "array",
  });

  return new Response(new Uint8Array(output), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type":
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition":
        'attachment; filename="meditech_inventory_template.xlsx"',
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "GET" && req.method !== "POST") {
    return jsonReply(405, { error: "Use GET or POST." });
  }

  const authorization = req.headers.get("Authorization");

  if (!authorization) {
    return jsonReply(401, {
      error: "Sign in before importing inventory.",
    });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: {
      headers: { Authorization: authorization },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: userData, error: userError } =
    await userClient.auth.getUser();

  if (userError || !userData.user) {
    return jsonReply(401, {
      error: "Your session is invalid or expired.",
    });
  }

  const server = createClient(supabaseUrl, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: account, error: accountError } = await server
    .from("accounts")
    .select("account_type")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (accountError || account?.account_type !== "staff") {
    return jsonReply(403, {
      error: "Only pharmacy staff can import inventory.",
    });
  }

  const { data: staff, error: staffError } = await server
    .from("staff_members")
    .select("branch_id, role")
    .eq("account_id", userData.user.id)
    .eq("is_active", true)
    .maybeSingle();

  if (staffError || !staff?.branch_id) {
    return jsonReply(403, {
      error: "Your account is not linked to an active pharmacy branch.",
    });
  }

  if (req.method === "GET") {
    return createTemplate();
  }

  try {
    const form = await req.formData();
    const uploadedFile = form.get("file");

    if (!(uploadedFile instanceof File)) {
      return jsonReply(400, {
        error: 'Upload a file using the form field named "file".',
      });
    }

    const file = uploadedFile;
    const fileName = file.name.trim();
    const extension = fileName.toLowerCase().split(".").pop();

    if (extension !== "csv" && extension !== "xlsx") {
      return jsonReply(400, {
        error: "Only CSV and XLSX files are supported.",
      });
    }

    if (file.size <= 0) {
      return jsonReply(400, { error: "The uploaded file is empty." });
    }

    if (file.size > MAX_FILE_SIZE) {
      return jsonReply(400, {
        error: "The maximum upload size is 2 MB.",
      });
    }

    const fileBuffer = await file.arrayBuffer();
    let sourceRows: unknown[][];

    if (extension === "csv") {
      const csvText = new TextDecoder("utf-8", {
        fatal: true,
      }).decode(fileBuffer);

      sourceRows = parseCsv(csvText);
    } else {
      const workbook = XLSX.read(new Uint8Array(fileBuffer), {
        type: "array",
        cellDates: false,
      });

      const firstSheetName = workbook.SheetNames[0];

      if (!firstSheetName) {
        return jsonReply(400, {
          error: "The Excel file does not contain a worksheet.",
        });
      }

      const worksheet = workbook.Sheets[firstSheetName];

      sourceRows = XLSX.utils.sheet_to_json(worksheet, {
        header: 1,
        raw: true,
        defval: "",
        blankrows: false,
      }) as unknown[][];
    }

    if (sourceRows.length < 2) {
      return jsonReply(400, {
        error: "The file must contain a header and at least one data row.",
      });
    }

    if (sourceRows.length - 1 > MAX_ROWS) {
      return jsonReply(400, {
        error: `The file exceeds the ${MAX_ROWS}-row limit.`,
      });
    }

    const { data: catalogue, error: catalogueError } = await server
      .from("medicines")
      .select("id, brand_name, strength")
      .eq("status", "active");

    if (catalogueError) {
      return jsonReply(500, {
        error: "Could not load the active medicine catalogue.",
      });
    }

    const parsedRows = parseRows(
      sourceRows,
      (catalogue ?? []) as CatalogueMedicine[],
    );

    if (parsedRows.length === 0) {
      return jsonReply(400, {
        error: "The file does not contain any import rows.",
      });
    }

    const validRows = parsedRows.filter(
      (row) =>
        row.errors.length === 0 &&
        row.matched_medicine_id !== null,
    ).length;

    const errorRows = parsedRows.length - validRows;

    const { data: batch, error: batchError } = await server
      .from("inventory_import_batches")
      .insert({
        branch_id: staff.branch_id,
        created_by: userData.user.id,
        file_name: fileName,
        file_type: extension,
        file_size_bytes: file.size,
        status: "reviewing",
        total_rows: parsedRows.length,
        valid_rows: validRows,
        error_rows: errorRows,
      })
      .select("id")
      .single();

    if (batchError || !batch) {
      return jsonReply(500, {
        error: "Could not create the import review batch.",
      });
    }

    for (
      let start = 0;
      start < parsedRows.length;
      start += INSERT_CHUNK_SIZE
    ) {
      const chunk = parsedRows.slice(
        start,
        start + INSERT_CHUNK_SIZE,
      ).map((row) => ({
        batch_id: batch.id,
        ...row,
      }));

      const { error: rowsError } = await server
        .from("inventory_import_rows")
        .insert(chunk);

      if (rowsError) {
        await server
          .from("inventory_import_batches")
          .delete()
          .eq("id", batch.id)
          .eq("branch_id", staff.branch_id);

        return jsonReply(500, {
          error: "Could not save all import rows. No inventory was changed.",
        });
      }
    }

    return jsonReply(200, {
      batch_id: batch.id,
      file_name: fileName,
      total_rows: parsedRows.length,
      valid_rows: validRows,
      error_rows: errorRows,
      status: "reviewing",
      message: "File parsed successfully. Review the rows before publishing.",
    });
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "An unexpected import error occurred.";

    return jsonReply(400, { error: message });
  }
});
