import { useState, useEffect } from "react";
import { entriesService } from "../services/api";

function AiInsightCard({ insight }) {
  const sourceBadge =
    insight.source === "mock_validation"
      ? { label: "Mock insight", color: "bg-yellow-700 text-yellow-200" }
      : insight.source === "manual_seed_validation"
      ? { label: "Seeded validation", color: "bg-orange-800 text-orange-200" }
      : null;

  return (
    <div className="bg-gray-800 rounded-lg p-4 space-y-3">
      <div className="flex items-center justify-between">
        <h3 className="font-semibold text-purple-300">✦ AI Insight</h3>
        <div className="flex items-center gap-2">
          {sourceBadge && (
            <span className={`text-xs px-2 py-0.5 rounded-full ${sourceBadge.color}`}>
              {sourceBadge.label}
            </span>
          )}
          {insight.mood?.primary && (
            <span className="text-xs bg-gray-700 text-gray-300 px-2 py-1 rounded-full">
              {insight.mood.primary}
            </span>
          )}
        </div>
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
  const [retrying, setRetrying] = useState(false);

  // Fetch insight and update state
  const loadInsight = async () => {
    try {
      const ins = await entriesService.getEntryInsight(entryId);
      setInsight(ins);
    } catch (e) {
      console.warn("No insight yet:", e);
    }
  };

  // Poll until OCR is done — stops once entry is ready to display
  useEffect(() => {
    const poll = setInterval(async () => {
      try {
        const data = await entriesService.getEntry(entryId);
        setEntry(data);
        if (data.status === "OCR_COMPLETE" || data.reviewStatus === "REVIEWED") {
          setStatus("ready");
          clearInterval(poll);
          if (data.aiStatus === "COMPLETE") {
            loadInsight();
          }
        }
      } catch (err) {
        console.error("Poll failed:", err);
      }
    }, 2000);

    return () => clearInterval(poll);
  }, [entryId]);

  // Poll AI status whenever QUEUED or ENRICHING — independent of OCR polling
  useEffect(() => {
    if (!entry) return;
    if (entry.aiStatus !== "QUEUED" && entry.aiStatus !== "ENRICHING") return;
    // Note: THROTTLED and FAILED are terminal — user must click retry

    const aiPoll = setInterval(async () => {
      try {
        const data = await entriesService.getEntry(entryId);
        setEntry(data);
        if (data.aiStatus === "COMPLETE") {
          clearInterval(aiPoll);
          loadInsight();
        } else if (
          data.aiStatus === "FAILED" ||
          data.aiStatus === "THROTTLED" ||
          (data.aiStatus !== "QUEUED" && data.aiStatus !== "ENRICHING")
        ) {
          clearInterval(aiPoll);
        }
      } catch (err) {
        console.error("AI status poll failed:", err);
      }
    }, 3000);

    return () => clearInterval(aiPoll);
  }, [entry?.aiStatus]);

  const aiStatusLabel =
    entry?.aiStatus === "COMPLETE"
      ? null
      : entry?.aiStatus === "QUEUED" || entry?.aiStatus === "ENRICHING"
      ? "✦ AI analysis in progress..."
      : entry?.aiStatus === "THROTTLED"
      ? "✦ AI busy — quota limit reached, retry later"
      : entry?.aiStatus === "FAILED"
      ? "✦ AI analysis failed"
      : null;

  const handleRetry = async () => {
    setRetrying(true);
    try {
      await entriesService.retryEnrichment(entryId);
      // Update local state to show Analyzing... immediately
      setEntry((prev) => prev ? { ...prev, aiStatus: "QUEUED" } : prev);
    } catch (e) {
      console.error("Retry failed:", e);
    } finally {
      setRetrying(false);
    }
  };

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
              <p className={`text-sm text-center ${entry?.aiStatus === "FAILED" ? "text-red-400" : "text-purple-400"}`}>
                {aiStatusLabel}
              </p>
            )}

            {(entry?.aiStatus === "FAILED" || entry?.aiStatus === "THROTTLED") && (
              <button
                onClick={handleRetry}
                disabled={retrying}
                className="w-full bg-purple-700 hover:bg-purple-600 disabled:opacity-50 text-white font-semibold py-2 rounded-lg text-sm"
              >
                {retrying ? "Queuing..." : "↺ Retry AI Analysis"}
              </button>
            )}

            {insight && <AiInsightCard insight={insight} />}
          </>
        )}
      </div>
    </div>
  );
}
