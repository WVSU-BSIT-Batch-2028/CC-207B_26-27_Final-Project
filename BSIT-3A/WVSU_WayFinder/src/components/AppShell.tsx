import { NavLink, Outlet, useLocation } from "react-router-dom";
import Logo from "./Logo";
import { BuildingIcon, DocIcon, HomeIcon, MapIcon, SparkIcon } from "./Icons";
import { isLiveConfigured } from "../lib/data";

const tabs = [
  { to: "/", label: "Home", Icon: HomeIcon, end: true },
  { to: "/map", label: "Map", Icon: MapIcon },
  { to: "/processes", label: "Processes", Icon: DocIcon },
  { to: "/directory", label: "Directory", Icon: BuildingIcon },
  { to: "/guide", label: "AI Guide", Icon: SparkIcon },
];

export default function AppShell() {
  const { pathname } = useLocation();
  // Schedule and search screens belong to Home.
  const homeActive = pathname === "/" || pathname.startsWith("/schedule") || pathname.startsWith("/search");
  return (
    <div className="shell">
      <header className="topbar">
        <Logo />
      </header>
      {!isLiveConfigured && (
        <div className="demo-banner" role="note">
          <strong>DEMO DATA</strong> — records below are placeholders, not official WVSU information.
        </div>
      )}
      <main className="content">
        <Outlet />
      </main>
      <nav className="bottom-nav" aria-label="Main">
        {tabs.map(({ to, label, Icon, end }) => (
          <NavLink key={to} to={to} end={end} className={({ isActive }) => `tab${isActive || (to === "/" && homeActive) ? " active" : ""}`}>
            <span className="tab-icon"><Icon /></span>
            <span>{label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}
