// Read-only integration probe. No account, collection or source writes.
import { CatalogService } from "../src/metadata/catalog.js";
const catalog = new CatalogService();
const start = Date.now();
const [calendar, picks] = await Promise.all([catalog.calendar(), catalog.picks()]);
const first = picks.data[0];
if (!first) throw new Error("Empty current-season catalog");
const [detail, episodes, characters, staff, search, artwork] = await Promise.all([
  catalog.subject(first.id), catalog.episodes(first.id, 0), catalog.credits(first.id, "characters"),
  catalog.credits(first.id, "persons"), catalog.search("葬送的芙莉莲", 0), catalog.artwork(first.id)
]);
console.log(JSON.stringify({ checkedAt: new Date().toISOString(), mode: "live-public-read", durationMs: Date.now() - start, days: calendar.length, picks: picks.data.length, subjectId: detail.id, episodes: episodes.data.length, characters: characters.length, staff: staff.length, searchResults: search.data.length, artworkState: artwork.state }));
