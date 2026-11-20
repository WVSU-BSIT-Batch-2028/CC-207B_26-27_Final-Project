import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { SearchIcon } from "./Icons";

export default function SearchBar({ initial = "", autoFocus = false }: { initial?: string; autoFocus?: boolean }) {
  const [value, setValue] = useState(initial);
  const navigate = useNavigate();

  function submit(e: FormEvent) {
    e.preventDefault();
    const q = value.trim();
    if (q) navigate(`/search?q=${encodeURIComponent(q)}`);
  }

  return (
    <form className="searchbar" role="search" onSubmit={submit}>
      <SearchIcon />
      <input
        type="search"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Search rooms, offices, buildings"
        aria-label="Search places, room codes and offices"
        autoFocus={autoFocus}
        enterKeyHint="search"
      />
    </form>
  );
}
