import { defineConfig } from "vite";

export default defineConfig({
  build: {
    emptyOutDir: true,
    outDir: "dist",
    lib: {
      entry: "src/main.ts",
      name: "PamphletRenderer",
      formats: ["iife"],
      fileName: () => "renderer.js"
    },
    rollupOptions: {
      output: {
        assetFileNames: "renderer.[ext]"
      }
    }
  },
  test: {
    environment: "jsdom"
  }
});
