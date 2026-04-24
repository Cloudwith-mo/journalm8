import { useState, useEffect } from "react";
import { authService, entriesService } from "../services/api";

function getEntryLabel(entry) {
  if (entry.reviewStatus === "REVIEWED" && entry.aiStatus === "COMPLETE") {
    return { text: "✓ Reviewed · Insight ready", color: "text-purple-400" };
  }
  if (
    entry.reviewStatus === "REVIEWED" &&
    (entry.aiStatus === "QUEUED" || entry.aiStatus === "ENRICHING")
  ) {
    return { text: "✓ Reviewed · Analyzing...", color: "text-blue-400" };
  }
  if (entry.reviewStatus === "REVIEWED" && entry.aiStatus === "THROTTLED") {
    return { text: "✓ Reviewed · AI busy — retry later", color: "text-orange-400" };
  }
  if (entry.reviewStatus === "REVIEWED" && entry.aiStatus === "FAILED") {
    return { text: "✓ Reviewed · AI failed — retry", color: "text-red-400" };
  }
  if (entry.reviewStatus === "REVIEWED") {
    return { text: "✓ Reviewed", color: "text-green-400" };
  }
  if (entry.status === "OCR_COMPLETE") {
    return { text: "Needs review", color: "text-yellow-400" };
  }
  if (entry.status === "OCR_FAILED") {
    return { text: "OCR failed", color: "text-red-400" };
  }
  return { text: "⏳ Processing...", color: "text-gray-400" };
}

export function HomeScreen({ onUpload, onSelectEntry, onWeeklyReflection }) {
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

  const reviewedCount = entries.filter((e) => e.reviewStatus === "REVIEWED").length;
  const insightCount = entries.filter((e) => e.aiStatus === "COMPLETE").length;

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
        <div className="grid grid-cols-3 gap-3 mb-6">
          <div className="bg-gray-800 p-4 rounded">
            <div className="text-2xl font-bold text-blue-400">
              {entries.length}
            </div>
            <div className="text-gray-400 text-xs mt-1">Entries</div>
          </div>
          <div className="bg-gray-800 p-4 rounded">
            <div className="text-2xl font-bold text-green-400">
              {reviewedCount}
            </div>
            <div className="text-gray-400 text-xs mt-1">Reviewed</div>
          </div>
          <div className="bg-gray-800 p-4 rounded">
            <div className="text-2xl font-bold text-purple-400">
              {insightCount}
            </div>
            <div className="text-gray-400 text-xs mt-1">AI Insights</div>
          </div>
        </div>

        {/* Primary CTA */}
        <button
          onClick={onUpload}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-4 rounded-lg text-lg mb-3 flex items-center justify-center gap-2"
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

        {/* Weekly Reflection CTA */}
        {reviewedCount >= 1 && onWeeklyReflection && (
          <button
            onClick={onWeeklyReflection}
            className="w-full bg-purple-700 hover:bg-purple-600 text-white font-semibold py-3 rounded-lg mb-4 flex items-center justify-center gap-2 text-sm"
          >
            ✦ Generate Weekly Reflection
          </button>
        )}

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
            entries.map((entry) => {
              const label = getEntryLabel(entry);
              return (
                <button
                  key={entry.entryId}
                  onClick={() => onSelectEntry(entry.entryId)}
                  className="w-full bg-gray-800 hover:bg-gray-700 p-4 rounded text-left transition"
                >
                  <div className="font-medium">
                    {entry.date || new Date(entry.createdAt || Date.now()).toLocaleDateString()}
                  </div>
                  <div className={`text-sm mt-1 ${label.color}`}>
                    {label.text}
                  </div>
                </button>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
