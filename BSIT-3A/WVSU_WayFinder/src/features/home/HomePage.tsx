import { Link } from "react-router-dom";
import SearchBar from "../../components/SearchBar";
import { BuildingIcon, ChatIcon, DocIcon, MapIcon } from "../../components/Icons";
import NextClassCard from "./NextClassCard";

const quick = [
  { to: "/map", label: "Campus Map", Icon: MapIcon },
  { to: "/processes", label: "Process Documents", Icon: DocIcon },
  { to: "/directory", label: "Find a Teacher", Icon: BuildingIcon },
  { to: "/guide", label: "Ask WayFinder", Icon: ChatIcon },
];

export default function HomePage() {
  return (
    <section className="home">
      <div className="home-main">
        <p className="eyebrow">WVSU WAYFINDER</p>
        <h1 className="greeting">Hi! Where do you need to go?</h1>
        <SearchBar />
        <NextClassCard />
      </div>
      <div className="home-side">
        <h2 className="section-label">Quick actions</h2>
        <div className="quick-grid">
          {quick.map(({ to, label, Icon }) => (
            <Link key={label} to={to} className="card quick">
              <span className="quick-icon"><Icon /></span>
              <span>{label}</span>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}
