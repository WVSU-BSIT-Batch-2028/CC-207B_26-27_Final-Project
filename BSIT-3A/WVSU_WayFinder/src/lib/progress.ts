// Step progress for each process, saved on this device.
import { useSyncExternalStore } from "react";

const KEY = "wf.process.progress.v1";
const listeners = new Set<() => void>();
let cache: Record<string, number[]> | null = null;

const read = (): Record<string, number[]> => {
  if (cache) return cache;
  try { cache = JSON.parse(localStorage.getItem(KEY) ?? "{}"); } catch { cache = {}; }
  return cache!;
};

export const progressStore = {
  get: (processId: string): number[] => read()[processId] ?? [],
  toggle(processId: string, position: number) {
    const done = new Set(progressStore.get(processId));
    if (done.has(position)) done.delete(position); else done.add(position);
    cache = { ...read(), [processId]: [...done].sort((a, b) => a - b) };
    try { localStorage.setItem(KEY, JSON.stringify(cache)); } catch { /* memory only */ }
    listeners.forEach((l) => l());
  },
  reset(processId: string) {
    const { [processId]: _drop, ...rest } = read();
    cache = rest;
    try { localStorage.setItem(KEY, JSON.stringify(cache)); } catch { /* memory only */ }
    listeners.forEach((l) => l());
  },
  subscribe: (l: () => void) => { listeners.add(l); return () => listeners.delete(l); },
  _reset: () => { cache = null; },
};

export function useProgress(processId: string): number[] {
  const snap = () => JSON.stringify(progressStore.get(processId));
  return JSON.parse(useSyncExternalStore(progressStore.subscribe, snap, snap)) as number[];
}
