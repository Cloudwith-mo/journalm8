import { useState, useEffect } from "react";
import { authService, agentsService } from "./services/api";
import { AuthScreen } from "./pages/AuthScreen";
import { HomeScreen } from "./pages/HomeScreen";
import { UploadScreen } from "./pages/UploadScreen";
import { EntryDetailScreen } from "./pages/EntryDetailScreen";
import { TranscriptReviewScreen } from "./pages/TranscriptReviewScreen";
import "./index.css";

export default function App() {
  const [screen, setScreen] = useState("loading");
  const [selectedEntry, setSelectedEntry] = useState(null);
  const [weeklyReflection, setWeeklyReflection] = useState(null);
  const [reflectionLoading, setReflectionLoading] = useState(false);
  const [reflectionError, setReflectionError] = useState(null);

  useEffect(() => {
    if (authService.isAuthenticated()) {
      setScreen("home");
    } else {
      setScreen("auth");
    }
  }, []);

  const handleAuthSuccess = () => {
    setScreen("home");
  };

  const handleUploadSuccess = (entryId) => {
    setSelectedEntry(entryId);
    setScreen("detail");
  };

  const handleReviewOpen = (entry) => {
    setSelectedEntry(entry);
    setScreen("review");
  };

  const handleBackToHome = () => {
    setSelectedEntry(null);
    setScreen("home");
  };

  const handleWeeklyReflection = async () => {
    setReflectionLoading(true);
    setReflectionError(null);
    setWeeklyReflection(null);
    setScreen("reflection");
    try {
      const result = await agentsService.runWeeklyReflection();
      setWeeklyReflection(result);
    } catch (err) {
      setReflectionError(err.message || "Failed to generate reflection");
    } finally {
      setReflectionLoading(false);
    }
  };

  return (
    <>
      {screen === "auth" && <AuthScreen onSuccess={handleAuthSuccess} />}
      {screen === "home" && (
        <HomeScreen
          onUpload={() => setScreen("upload")}
          onSelectEntry={(entryId) => {
            setSelectedEntry(entryId);
            setScreen("detail");
          }}
          onWeeklyReflection={handleWeeklyReflection}
        />
      )}
      {screen === "upload" && (
        <UploadScreen
          onSuccess={handleUploadSuccess}
          onCancel={() => setScreen("home")}
        />
      )}
      {screen === "detail" && (
        <EntryDetailScreen
          entryId={selectedEntry}
          onReview={handleReviewOpen}
          onBack={handleBackToHome}
        />
      )}
      {screen === "review" && (
        <TranscriptReviewScreen
          entry={selectedEntry}
          onBack={handleBackToHome}
        />
      )}
      {screen === "reflection" && (
        <WeeklyReflectionScreen
          loading={reflectionLoading}
          reflection={weeklyReflection}
          error={reflectionError}
          onBack={() => setScreen("home")}
        />
      )}
    </>
  );
}

function WeeklyReflectionScreen({ loading, reflection, error, onBack }) {
  return (
    <div className="min-h-screen bg-gray-900 text-white">
      <div className="bg-gray-800 p-4 flex items-center">
        <button onClick={onBack} className="text-gray-400 hover:text-white mr-4">
          ← Back
        </button>
        <h1 className="text-xl font-bold">Weekly Reflection</h1>
      </div>

      <div className="max-w-md mx-auto px-4 py-6 space-y-4">
        {loading && (
          <div className="text-center py-12">
            <div className="text-4xl mb-4 animate-pulse">✦</div>
            <p className="text-purple-300">Generating your weekly reflection...</p>
            <p className="text-gray-500 text-sm mt-2">This may take 15–30 seconds</p>
          </div>
        )}

        {error && (
          <div className="bg-red-900/40 border border-red-700 text-red-300 p-4 rounded-lg">
            <p className="font-semibold">Could not generate reflection</p>
            <p className="text-sm mt-1">{error}</p>
          </div>
        )}

        {reflection && (
          <>
            <div className="bg-gray-800 p-4 rounded-lg">
              <p className="text-purple-300 text-xs font-semibold uppercase tracking-wide mb-2">
                Week of {reflection.weekStart}
              </p>
              <p className="text-gray-100 leading-relaxed">{reflection.weeklySummary}</p>
            </div>

            {reflection.dominantThemes?.length > 0 && (
              <div className="bg-gray-800 p-4 rounded-lg">
                <p className="text-gray-400 text-xs mb-2">Dominant themes</p>
                <div className="flex flex-wrap gap-2">
                  {reflection.dominantThemes.map((t) => (
                    <span key={t} className="bg-purple-900 text-purple-200 text-xs px-2 py-1 rounded-full">
                      {t}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {reflection.wins?.length > 0 && (
              <div className="bg-gray-800 p-4 rounded-lg">
                <p className="text-green-400 text-xs font-semibold mb-2">Wins</p>
                <ul className="space-y-1">
                  {reflection.wins.map((w, i) => (
                    <li key={i} className="text-gray-300 text-sm">✓ {w}</li>
                  ))}
                </ul>
              </div>
            )}

            {reflection.struggles?.length > 0 && (
              <div className="bg-gray-800 p-4 rounded-lg">
                <p className="text-yellow-400 text-xs font-semibold mb-2">Struggles</p>
                <ul className="space-y-1">
                  {reflection.struggles.map((s, i) => (
                    <li key={i} className="text-gray-300 text-sm">• {s}</li>
                  ))}
                </ul>
              </div>
            )}

            {reflection.repeatedLoop && (
              <div className="bg-gray-800 p-4 rounded-lg">
                <p className="text-orange-400 text-xs font-semibold mb-1">Pattern to watch</p>
                <p className="text-gray-300 text-sm">{reflection.repeatedLoop}</p>
              </div>
            )}

            {reflection.recommendedFocus && (
              <div className="bg-blue-900/40 border border-blue-700 p-4 rounded-lg">
                <p className="text-blue-300 text-xs font-semibold mb-1">Focus for next week</p>
                <p className="text-white text-sm font-medium">{reflection.recommendedFocus}</p>
              </div>
            )}

            {reflection.reflectionQuestions?.length > 0 && (
              <div className="bg-gray-800 p-4 rounded-lg">
                <p className="text-gray-400 text-xs mb-2">Questions to sit with</p>
                <ul className="space-y-2">
                  {reflection.reflectionQuestions.map((q, i) => (
                    <li key={i} className="text-blue-300 text-sm italic">→ {q}</li>
                  ))}
                </ul>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
