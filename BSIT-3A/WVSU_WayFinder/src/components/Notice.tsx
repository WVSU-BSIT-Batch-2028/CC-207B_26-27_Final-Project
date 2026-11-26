export default function Notice({ children, tone = "warn" }: { children: React.ReactNode; tone?: "warn" | "info" }) {
  return <div className={`notice ${tone}`} role="status">{children}</div>;
}
