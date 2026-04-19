import { useState, useEffect } from "react";
import { authService, entriesService } from "../services/api";

export function HomeScreen({ onUpload, onSelectEntry }) {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadEntries();
  }, []);

  const loadEntries = async () => {
    try {
      setLoading(true);
      const data = await entriesService.getEntries();
      setEntries(data);
    } catch (error) {
      console.error("Failed to load entries:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    authService.signOut();
    window.location.reload();
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white pb-20">
      {/* Header */}
      <div className="bg-gray-800 p-4 flex justify-between items-center">
        <h1 className="text-2xl font-bold">JournalM8</h1>
        <button
          onClick={handleLogout}
          className="bg-gray-700 hover:bg-gray-600 px-4 py-2 rounded text-sm"
        >
          Sign Out
        </button>
      </div>

      <div className="max-w-md mx-auto px-4 py-6">
        {/* User info */}
        <div className="text-gray-400 text-sm mb-6">
          Signed in as {authService.getEmail()}
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div className="bg-gray-800 p-4 rounded">
            <div className="text-2xl font-bold text-blue-400">
              {entries.length}
            </div>
            <div className="text-gray-400 text-sm">Total Entries</div>
          </div>
          <div className="bg-gray-800 p-4 rounded">
            <div className="text-2xl font-bold text-green-400">
              {entries.filter((e) => e.status === "OCR_COMPLETE" || e.status === "REVIEWED").length}
            </div>
            <div className="text-gray-400 text-sm">Processed</div>
          </div>
        </div>

        {/* Primary CTA */}
        <button
          onClick={onUpload}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-4 rounded-lg text-lg mb-4 flex items-center justify-center gap-2"
        >
          <svg
            className="w-6 h-6"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 4v16m8-8H4"
            />
          </svg>
          New Entry
        </button>

        {/* Recent Entries */}
        <div className="space-y-2">
          <h2 className="text-lg font-semibold text-gray-300 mb-3">
            Recent Entries
          </h2>
          {loading ? (
            <div className="text-gray-500 text-center py-8">Loading...</div>
          ) : entries.length === 0 ? (
            <div className="text-gray-500 text-center py-8">
              No entries yet. Start by uploading a journal image.
            </div>
          ) : (
            entries.map((entry) => (
              <button
                key={entry.entryId}
                onClick={() => onSelectEntry(entry.entryId)}
                className="w-full bg-gray-800 hover:bg-gray-700 p-4 rounded text-left transition"
              >
                <div className="font-medium">{entry.date || new Date().toLocaleDateString()}</div>
                <div className="text-gray-400 text-sm">
                  {entry.status === "OCR_COMPLETE" || entry.status === "REVIEWED"
                    ? "✓ Processed"
                    : "⏳ Processing..."}
                </div>
              </button>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
