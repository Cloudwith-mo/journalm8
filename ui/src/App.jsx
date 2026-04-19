import { useState, useEffect } from "react";
import { authService } from "./services/api";
import { AuthScreen } from "./pages/AuthScreen";
import { HomeScreen } from "./pages/HomeScreen";
import { UploadScreen } from "./pages/UploadScreen";
import { EntryDetailScreen } from "./pages/EntryDetailScreen";
import { TranscriptReviewScreen } from "./pages/TranscriptReviewScreen";
import "./index.css";

export default function App() {
  const [screen, setScreen] = useState("loading");
  const [selectedEntry, setSelectedEntry] = useState(null);

  useEffect(() => {
    // Check if user is already logged in
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
    </>
  );
}
