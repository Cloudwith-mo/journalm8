import { useState } from "react";
import { entriesService } from "../services/api";

export function TranscriptReviewScreen({ entry, onSave, onBack }) {
  const [rawText, setRawText] = useState(entry?.rawText || "");
  const [correctedText, setCorrectedText] = useState(
    entry?.correctedText || entry?.rawText || ""
  );
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  const handleSave = async () => {
    setSaving(true);
    try {
      const entryId = entry.entryId;
      await entriesService.updateEntryTranscript(entryId, correctedText);
      setSaved(true);
      setTimeout(() => onBack(), 1000);
    } catch (err) {
      console.error("Save failed:", err);
      alert("Failed to save entry. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* Header */}
      <div className="bg-gray-800 p-4 flex items-center justify-between sticky top-0 z-10">
        <button
          onClick={onBack}
          className="text-gray-400 hover:text-white"
          disabled={saving}
        >
          ← Back
        </button>
        <h1 className="text-lg font-bold">Review</h1>
        <div className="w-8" />
      </div>

      <div className="max-w-md mx-auto px-4 py-6 pb-24">
        {saved ? (
          <div className="text-center space-y-4">
            <div className="text-4xl">✓</div>
            <p className="text-green-400 font-semibold">Saved successfully!</p>
          </div>
        ) : (
          <div className="space-y-4">
            {/* Original Text */}
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">
                Original OCR
              </label>
              <div className="bg-gray-800 p-4 rounded text-gray-300 text-sm max-h-32 overflow-y-auto">
                {rawText || "No text extracted"}
              </div>
            </div>

            {/* Corrected Text */}
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2">
                Your version
              </label>
              <textarea
                value={correctedText}
                onChange={(e) => setCorrectedText(e.target.value)}
                placeholder="Edit the transcript or add your notes here..."
                className="w-full bg-gray-800 text-white p-4 rounded border border-gray-700 focus:border-blue-500 focus:outline-none min-h-32 resize-none"
                disabled={saving}
              />
            </div>

            {/* Save Button */}
            <button
              onClick={handleSave}
              disabled={saving}
              className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white font-semibold py-3 rounded-lg transition"
            >
              {saving ? "Saving..." : "Save Entry"}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
