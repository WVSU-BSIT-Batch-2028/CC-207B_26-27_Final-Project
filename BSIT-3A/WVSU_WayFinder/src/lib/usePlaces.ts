import { useCallback, useEffect, useState } from "react";
import type { DataResult } from "./types";

type State<T> =
  | { state: "loading" }
  | { state: "done"; result: DataResult<T> }
  | { state: "error" };

export type Async<T> = State<T> & { reload: () => void };

/** Runs a data call whenever `key` changes (or `reload()` is called); ignores stale responses. */
export function useAsync<T>(key: string, run: () => Promise<DataResult<T>>): Async<T> {
  const [value, setValue] = useState<State<T>>({ state: "loading" });
  const [attempt, setAttempt] = useState(0);
  const reload = useCallback(() => setAttempt((n) => n + 1), []);

  useEffect(() => {
    let cancelled = false;
    setValue({ state: "loading" });
    run().then(
      (result) => !cancelled && setValue({ state: "done", result }),
      () => !cancelled && setValue({ state: "error" }),
    );
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, attempt]);

  return { ...value, reload } as Async<T>;
}
