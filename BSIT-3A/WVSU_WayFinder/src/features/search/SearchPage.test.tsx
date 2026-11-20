import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import SearchPage from "./SearchPage";

function renderAt(url: string) {
  return render(
    <MemoryRouter initialEntries={[url]}>
      <Routes>
        <Route path="/search" element={<SearchPage />} />
        <Route path="*" element={<div>other</div>} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("SearchPage", () => {
  it("known room: shows code, building, floor, and a Show on Map link using the place ID", async () => {
    renderAt("/search?q=cb%20203");
    expect(await screen.findByText("Demo Room CB 203")).toBeInTheDocument();
    expect(screen.getByText("CB203")).toBeInTheDocument();
    expect(screen.getByText("Demo College Building")).toBeInTheDocument();
    expect(screen.getByText("2")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /show on map/i })).toHaveAttribute("href", "/map?to=room-demo-cb-203");
    expect(screen.getByRole("link", { name: /view details/i })).toHaveAttribute("href", "/directory/room-demo-cb-203");
  });

  it("unknown room: keeps what was typed and offers another search", async () => {
    renderAt("/search?q=XY%20999");
    expect(await screen.findByText(/No match for/)).toHaveTextContent("XY 999");
    const input = screen.getByRole("searchbox");
    expect(input).toHaveValue("XY 999");
    await userEvent.clear(input);
    await userEvent.type(input, "cb101{Enter}");
    expect(await screen.findByText("Demo Room CB 101")).toBeInTheDocument(); // the second search ran
  });
});
