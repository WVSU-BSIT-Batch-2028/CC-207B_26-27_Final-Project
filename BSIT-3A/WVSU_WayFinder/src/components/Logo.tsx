import { useState } from "react";
import logo from "../assets/wayfinder-logo.png";

/** Official logo; falls back to a text placeholder if the image fails to load. */
export default function Logo() {
  const [failed, setFailed] = useState(false);
  if (failed) return <span className="logo-text">WVSU WayFinder</span>;
  return <img className="logo" src={logo} alt="WVSU WayFinder" onError={() => setFailed(true)} />;
}
