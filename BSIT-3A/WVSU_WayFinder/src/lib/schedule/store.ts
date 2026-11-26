// Private schedule storage on THIS device (browser localStorage). Nothing is sent to a server.
// Cloud sync needs Supabase Auth + supabase/migrations/0003_schedule.sql (not wired yet).
import { useSyncExternalStore } from "react";
import type { ClassSession } from "./types";

const CLASSES = "wf.schedule.classes.v1";
const IMAGE = "wf.schedule.image.v1";

type Listener = () => void;
const listeners = new Set<Listener>();
let cache: ClassSession[] | null = null;

function read(): ClassSession[] {
  if (cache) return cache;
  try {
    cache = JSON.parse(localStorage.getItem(CLASSES) ?? "[]") as ClassSession[];
  } catch {
    cache = [];
  }
  return cache;
}

function write(next: ClassSession[]) {
  cache = next;
  try {
    localStorage.setItem(CLASSES, JSON.stringify(next));
  } catch {
    /* storage blocked: keep in memory for this visit */
  }
  listeners.forEach((l) => l());
}

export const scheduleStore = {
  list: read,
  get: (id: string) => read().find((c) => c.id === id),
  save(c: ClassSession) {
    const all = read();
    write(all.some((x) => x.id === c.id) ? all.map((x) => (x.id === c.id ? c : x)) : [...all, c]);
  },
  remove(id: string) {
    write(read().filter((c) => c.id !== id));
  },
  subscribe(l: Listener) {
    listeners.add(l);
    return () => listeners.delete(l);
  },
  getImage(): string | null {
    try {
      return localStorage.getItem(IMAGE);
    } catch {
      return null;
    }
  },
  setImage(dataUrl: string | null) {
    try {
      if (dataUrl) localStorage.setItem(IMAGE, dataUrl);
      else localStorage.removeItem(IMAGE);
    } catch {
      throw new Error("This browser blocked saving the image.");
    }
    listeners.forEach((l) => l());
  },
  /** test helper */
  _reset() {
    cache = null;
  },
};

export function useClasses(): ClassSession[] {
  return useSyncExternalStore(scheduleStore.subscribe, scheduleStore.list, scheduleStore.list);
}

export const newId = () => (crypto.randomUUID ? crypto.randomUUID() : `c-${Date.now()}-${Math.random().toString(36).slice(2)}`);

/** Downscale a picked image to a JPEG data URL (keeps the stored copy small). */
export async function downscaleImage(file: File, maxSide = 1400): Promise<string> {
  const bitmap = await createImageBitmap(file);
  const scale = Math.min(1, maxSide / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  canvas.getContext("2d")!.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL("image/jpeg", 0.8);
}
