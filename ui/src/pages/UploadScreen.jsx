import { useState, useRef } from "react";
import { uploadService } from "../services/api";

export function UploadScreen({ onSuccess, onCancel }) {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState("");
  const fileInputRef = useRef(null);
  const cameraInputRef = useRef(null);

  const handleFileSelect = async (file) => {
    if (!file) return;

    setError("");
    setUploading(true);
    setProgress(0);

    try {
      // Get presigned URL
      const presignData = await uploadService.presignUpload(file.name);
      const { uploadUrl, entryId } = presignData;

      // Upload to S3
      setProgress(50);
      await uploadService.uploadImage(uploadUrl, file);
      
      setProgress(100);

      // Success
      setTimeout(() => {
        onSuccess(entryId);
      }, 500);
    } catch (err) {
      setError(err.message || "Upload failed");
      setUploading(false);
      setProgress(0);
    }
  };

  const handleCamera = () => {
    cameraInputRef.current?.click();
  };

  const handleGallery = () => {
    fileInputRef.current?.click();
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* Header */}
      <div className="bg-gray-800 p-4 flex justify-between items-center">
        <h1 className="text-2xl font-bold">New Entry</h1>
        <button
          onClick={onCancel}
          disabled={uploading}
          className="text-gray-400 hover:text-white disabled:opacity-50"
        >
          ✕
        </button>
      </div>

      <div className="max-w-md mx-auto px-4 py-8">
        {uploading ? (
          <div className="space-y-4">
            <div className="text-center">
              <div className="text-4xl mb-4">📤</div>
              <p className="text-gray-300 mb-4">Uploading...</p>
            </div>
            <div className="bg-gray-800 rounded-full h-2 overflow-hidden">
              <div
                className="bg-blue-600 h-full transition-all duration-300"
                style={{ width: `${progress}%` }}
              />
            </div>
            <p className="text-center text-gray-400 text-sm">{progress}%</p>
          </div>
        ) : error ? (
          <div className="space-y-4">
            <div className="bg-red-900 border border-red-700 p-4 rounded">
              <p className="text-red-200">{error}</p>
            </div>
            <button
              onClick={() => {
                setError("");
              }}
              className="w-full bg-gray-700 hover:bg-gray-600 text-white py-2 rounded"
            >
              Try Again
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            <p className="text-gray-300 text-center">
              Take a photo of your journal or upload an image
            </p>

            <button
              onClick={handleCamera}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-4 rounded-lg flex items-center justify-center gap-3"
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
                  d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"
                />
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"
                />
              </svg>
              Take Photo
            </button>

            <button
              onClick={handleGallery}
              className="w-full bg-gray-700 hover:bg-gray-600 text-white font-semibold py-4 rounded-lg flex items-center justify-center gap-3"
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
                  d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
              Choose from Gallery
            </button>
          </div>
        )}

        <input
          ref={cameraInputRef}
          type="file"
          accept="image/*"
          capture="environment"
          onChange={(e) => handleFileSelect(e.target.files?.[0])}
          className="hidden"
        />

        <input
          ref={fileInputRef}
          type="file"
          accept="image/png,image/jpeg"
          onChange={(e) => handleFileSelect(e.target.files?.[0])}
          className="hidden"
        />
      </div>
    </div>
  );
}
