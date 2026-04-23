import { useState, useEffect } from "react";
import { entriesService } from "../services/api";

function AiInsightCard({ insight }) {
  return (
    <div className="bg-gray-800 rounded-lg p-4 space-y-3">
      <div className="flex items-center justify-between">
        <h3 className="font-semibold text-purple-300">✦ AI Insight</h3>
        {insight.mood?.primary && (
          <span className="text-xs bg-gray-700 text-gray-300 px-2 py-1 rounded-full">
            {insight.mood.primary}
          </span>
        )}
      </div>

      {insight.summary && (
        <p className="text-gray-300 text-sm leading-relaxed">{insight.summary}</p>
      )}

      {insight.themes?.length > 0 && (
        <div>
          <p className="text-gray-500 text-xs mb-1">Themes</p>
          <div className="flex flex-wrap gap-1">
            {insight.themes.map((t) => (
              <span key={t} className="text-xs bg-purple-900 text-purple-200 px-2 py-0.5 rounded-full">
                {t}
              </span>
            ))}
          </div>
        </div>
      )}

      {insight.keyInsights?.length > 0 && (
        <div>
          <p className="text-gray-500 text-xs mb-1">Key insights</p>
          <ul className="space-y-1">
            {insight.keyInsights.map((k, i) => (
              <li key={i} className="text-gray-300 text-sm">• {k}</li>
            ))}
          </ul>
        </div>
      )}

      {insight.reflectionQuestions?.length > 0 && (
        <div>
          <p className="text-gray-500 text-xs mb-1">Reflect on this</p>
          <ul className="space-y-1">
            {insight.reflectionQuestions.map((q, i) => (
              <li key={i} className="text-blue-300 text-sm italic">→ {q}</li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

export function EntryDetailScreen({ entryId, onReview, onBack }) {
  const [status, setStatus] = useState("processing");
  const [entry, setEntry] = useState(null);
  const [insight, setInsight] = useState(null);

  useEffect(() => {
    // Poll for entry status
    const poll = setInterval(async () => {
      try {
        const data = await entriesService.getEntry(entryId);
        setEntry(data);
        if (data.status === "OCR_COMPLETE" || data.reviewStatus === "REVIEWED") {
          setStatus("ready");
          clearInterval(poll);
          // Fetch AI insight if available
          if (data.aiStatus === "COMPLETE") {
            try {
              const ins = await entriesService.getEntryInsight(entryId);
              setInsight(ins);
            } catch (e) {
              console.warn("No insight yet:", e);
            }
          }
        }
      } catch (err) {
        console.error("Poll failed:", err);
      }
    }, 2000);

    return () => clearInterval(poll);
  }, [entryId]);

  const aiStatusLabel =
    entry?.aiStatus === "COMPLETE"
      ? null // shown via AiInsightCard
      : entry?.aiStatus === "QUEUED" || entry?.aiStatus === "ENRICHING"
      ? "✦ AI analysis in progress..."
      : null;

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

      <div className="max-w-md mx-auto px-4 py-8 space-y-4">
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
          <>
            <div className="bg-gray-800 p-4 rounded">
              <p className="text-gray-400 text-sm">Raw transcription:</p>
              <p className="mt-2 text-white">
                {entry?.rawText || "No text extracted"}
              </p>
            </div>

            {entry?.reviewStatus !== "REVIEWED" && (
              <button
                onClick={() => onReview(entry)}
                className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg"
              >
                Review & Edit Transcript
              </button>
            )}

            {entry?.reviewStatus === "REVIEWED" && !insight && (
              <button
                onClick={() => onReview(entry)}
                className="w-full bg-gray-700 hover:bg-gray-600 text-white font-semibold py-3 rounded-lg text-sm"
              >
                Edit Transcript
              </button>
            )}

            {aiStatusLabel && (
              <p className="text-purple-400 text-sm text-center">{aiStatusLabel}</p>
            )}

            {insight && <AiInsightCard insight={insight} />}
          </>
        )}
      </div>
    </div>
  );
}
