import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import DirectoryPage from "./DirectoryPage";
import FacultyDetailPage from "./FacultyDetailPage";
import PlaceDetailPage from "./PlaceDetailPage";

const renderDir = (url = "/directory") =>
  render(
    <MemoryRouter initialEntries={[url]}>
      <Routes>
        <Route path="/directory" element={<DirectoryPage />}>
          <Route path="faculty/:recordId" element={<FacultyDetailPage />} />
          <Route path=":placeId" element={<PlaceDetailPage />} />
        </Route>
      </Routes>
    </MemoryRouter>,
  );

describe("Directory (demo fixtures)", () => {
  it("lists only published + verified teachers", async () => {
    renderDir();
    expect(await screen.findByRole("link", { name: "Demo Prof. Maria Mapped" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Demo Prof. Juan Unmapped" })).toBeInTheDocument();
    expect(screen.queryByText(/Hidden Unpublished/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Hidden Pending/)).not.toBeInTheDocument();
  });

  it("category filters: Faculty shows only teachers; Rooms shows only rooms", async () => {
    renderDir();
    await screen.findByRole("link", { name: "Demo Prof. Maria Mapped" });
    await userEvent.click(screen.getByRole("tab", { name: "Faculty" }));
    expect(screen.queryByText("Demo Library")).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole("tab", { name: "Rooms" }));
    expect(await screen.findByText("Demo Room CB 203")).toBeInTheDocument();
    expect(screen.queryByText("Demo Administration Building")).not.toBeInTheDocument(); // buildings hidden
    expect(screen.queryByRole("link", { name: "Demo Prof. Maria Mapped" })).not.toBeInTheDocument();
  });

  it("faculty detail with a verified office link: position, department, college and Show on map", async () => {
    renderDir("/directory/faculty/demo-fd-1");
    const card = await screen.findByRole("article", { name: "Demo Prof. Maria Mapped" });
    expect(within(card).getByText("Demo Associate Professor")).toBeInTheDocument();
    expect(within(card).getByText("Demo Department of Computing")).toBeInTheDocument();
    expect(within(card).getByText(/Demo College of Information and Communications Technology/)).toBeInTheDocument();
    expect(within(card).getByRole("link", { name: /show on map/i })).toHaveAttribute("href", "/map?to=room-demo-cb-203");
  });

  it("faculty detail without an office link: Office location unconfirmed, no map button", async () => {
    renderDir("/directory/faculty/demo-fd-2");
    const card = await screen.findByRole("article", { name: "Demo Prof. Juan Unmapped" });
    expect(within(card).getByText("Office location unconfirmed")).toBeInTheDocument();
    expect(within(card).queryByRole("link", { name: /show on map/i })).not.toBeInTheDocument();
  });

  it("hidden profiles can't be opened by ID either", async () => {
    renderDir("/directory/faculty/demo-fd-5");
    expect(await screen.findByText("Profile not available")).toBeInTheDocument();
  });

  it("search by name", async () => {
    renderDir();
    await userEvent.type(screen.getByRole("searchbox"), "juan{Enter}");
    expect(await screen.findByRole("link", { name: "Demo Prof. Juan Unmapped" })).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Demo Prof. Maria Mapped" })).not.toBeInTheDocument();
  });
});
