import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { renderApp } from "../../test-utils";
import { progressStore } from "../../lib/progress";

beforeEach(() => progressStore._reset());

describe("Student Processes (demo fixtures)", () => {
  it("searchable list", async () => {
    renderApp("/processes");
    expect(await screen.findByText("Demo Enrollment")).toBeInTheDocument();
    await userEvent.type(screen.getByRole("searchbox"), "clearance{Enter}");
    expect(await screen.findByText("Demo Clearance")).toBeInTheDocument();
    expect(screen.queryByText("Demo Enrollment")).not.toBeInTheDocument();
  });

  it("detail: before you start, documents, ordered steps, saved progress, show office on map", async () => {
    renderApp("/processes/proc-demo-enrollment");
    expect(await screen.findByText("Before you start")).toBeInTheDocument();
    expect(screen.getByText("Assessment form")).toBeInTheDocument();
    expect(screen.getByText(/0 of 3/)).toBeInTheDocument();
    const bar = screen.getByRole("region", { name: "Next step" });
    expect(within(bar).getByRole("link", { name: "Take me there" })).toHaveAttribute("href", "/map?to=office-demo-registrar");
    await userEvent.click(within(bar).getByRole("button", { name: /mark step complete/i }));
    expect(screen.getByText(/1 of 3/)).toBeInTheDocument();
    expect(within(screen.getByRole("region", { name: "Next step" })).getByText("Cashier")).toBeInTheDocument();
    expect(JSON.parse(localStorage.getItem("wf.process.progress.v1")!)).toEqual({ "proc-demo-enrollment": [1] });
  });

  it("unknown guide → clear empty state", async () => {
    renderApp("/processes/nope");
    expect(await screen.findByText("Guide not available")).toBeInTheDocument();
  });
});
