import { useEffect, useRef, useState } from "react";
import { ReminderScheduler, systemClock } from "../../lib/schedule/reminders";
import { useClasses } from "../../lib/schedule/store";
import type { ClassSession } from "../../lib/schedule/types";
import { formatClock } from "../../lib/time";

export type NotifStatus = "granted" | "denied" | "default" | "unsupported";
export const notificationStatus = (): NotifStatus =>
  typeof Notification === "undefined" ? "unsupported" : (Notification.permission as NotifStatus);
export async function requestNotifications(): Promise<NotifStatus> {
  if (typeof Notification === "undefined") return "unsupported";
  return (await Notification.requestPermission()) as NotifStatus;
}

const message = (c: ClassSession) =>
  `${c.subject} at ${formatClock(c.start)} · Room ${c.roomCodeRaw}${c.professor ? ` · ${c.professor}` : ""}`;

/** Keeps one reminder per class in sync with the schedule; shows a notification or an in-app banner. */
export default function ReminderHost() {
  const classes = useClasses();
  const [toast, setToast] = useState<string | null>(null);
  const scheduler = useRef<ReminderScheduler | null>(null);
  if (!scheduler.current) {
    scheduler.current = new ReminderScheduler(systemClock, (c) => {
      if (notificationStatus() === "granted") new Notification("Class reminder", { body: message(c) });
      setToast(message(c));
    });
  }
  useEffect(() => {
    scheduler.current!.sync(classes);
  }, [classes]);
  useEffect(() => () => scheduler.current!.cancelAll(), []);
  if (!toast) return null;
  return (
    <div className="toast" role="alert">
      <strong>Class reminder</strong> {toast}
      <button className="link-btn" onClick={() => setToast(null)}>Dismiss</button>
    </div>
  );
}
