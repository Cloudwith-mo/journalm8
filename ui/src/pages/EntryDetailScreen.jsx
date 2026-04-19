import { useState, useEffect } from "react";
import { entriesService } from "../services/api";

export function EntryDetailScreen({ entryId, onReview, onBack }) {
  const [status, setStatus] = useState("processing");
  const [entry, setEntry] = useState(null);

  useEffect(() => {
    // Poll for entry status
    const poll = setInterval(async () => {
      try {
        const data = await entriesService.getEntry(entryId);
        setEntry(data);
        if (data.status === "OCR_COMPLETE" || data.status === "REVIEWED") {
          setStatus("ready");
          clearInterval(poll);
        }
      } catch (err) {
        console.error("Poll failed:", err);
      }
    }, 2000);

    return () => clearInterval(poll);
  }, [entryId]);

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* Header */}
      <div className="bg-gray-800 p-4 flex items-center">
        <button
          onClick={onBack}
          className="text-gray-400 hover:text-white mr-4"
        >
          ← Back
        </button>
        <h1 className="text-2xl font-bold">Entry</h1>
      </div>

      <div className="max-w-md mx-auto px-4 py-8">
        {status === "processing" ? (
          <div className="space-y-4">
            <div className="text-center">
              <div className="animate-spin text-4xl mb-4">⚙️</div>
              <p className="text-gray-300">Processing your image...</p>
              <p className="text-gray-500 text-sm mt-2">
                This usually takes 10-30 seconds
              </p>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="bg-gray-800 p-4 rounded">
              <p className="text-gray-400 text-sm">Raw transcription:</p>
              <p className="mt-2 text-white">
                {entry?.rawText || "No text extracted"}
              </p>
            </div>

            <button
              onClick={() => onReview(entry)}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg"
            >
              Review & Edit Transcript
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
