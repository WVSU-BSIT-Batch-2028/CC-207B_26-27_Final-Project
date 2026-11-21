import type { ReactNode } from "react";

const base = { width: 22, height: 22, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, "aria-hidden": true };
const I = (children: ReactNode) => () => <svg {...base}>{children}</svg>;

export const HomeIcon = I(<><path d="M4 11l8-7 8 7" /><path d="M6 10v10h12V10" /></>);
export const MapIcon = I(<><path d="M9 4L3 6v14l6-2 6 2 6-2V4l-6 2-6-2z" /><path d="M9 4v14M15 6v14" /></>);
export const DocIcon = I(<><path d="M7 3h7l4 4v14H7z" /><path d="M14 3v4h4M10 12h5M10 16h5" /></>);
export const BuildingIcon = I(<><path d="M5 21V4h9v17M14 9h5v12" /><path d="M8 8h3M8 12h3M8 16h3" /></>);
export const SparkIcon = I(<path d="M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2z" />);
export const SearchIcon = I(<><circle cx="11" cy="11" r="6.5" /><path d="M16 16l4 4" /></>);
export const PinIcon = I(<><path d="M12 21s7-6 7-11a7 7 0 10-14 0c0 5 7 11 7 11z" /><circle cx="12" cy="10" r="2.5" /></>);
export const CalendarIcon = I(<><rect x="4" y="5" width="16" height="15" rx="2" /><path d="M4 10h16M9 3v4M15 3v4" /></>);
export const ChatIcon = I(<path d="M5 5h14v10H10l-5 4z" />);
export const ClockIcon = I(<><circle cx="12" cy="12" r="8" /><path d="M12 8v4l3 2" /></>);
export const UserIcon = I(<><circle cx="12" cy="8" r="3.5" /><path d="M5 20c1-4 4-6 7-6s6 2 7 6" /></>);
export const UploadIcon = I(<><path d="M12 16V4M7 9l5-5 5 5" /><path d="M5 20h14" /></>);
export const CheckIcon = I(<path d="M5 12l4 4 10-10" />);
export const RouteIcon = I(<><circle cx="6" cy="18" r="2" /><circle cx="18" cy="6" r="2" /><path d="M8 18h6a3 3 0 000-6H10a3 3 0 010-6h6" /></>);
export const BellIcon = I(<><path d="M6 16V11a6 6 0 1112 0v5l2 2H4z" /><path d="M10 20a2 2 0 004 0" /></>);
