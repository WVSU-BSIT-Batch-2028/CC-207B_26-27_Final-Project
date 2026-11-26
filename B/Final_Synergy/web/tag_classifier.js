import { FilesetResolver, TextClassifier } from './mediapipe/text_bundle.mjs';

let loading;

// Load the model once, even if both boxes ask at the same time.
// A failed load is forgotten so the next click can retry.
function loadModel() {
  loading ??= (async () => {
    const files = await FilesetResolver.forTextTasks('./mediapipe/wasm');
    return TextClassifier.createFromModelPath(files, './tag_model/tag_model.tflite');
  })().catch((error) => {
    loading = undefined;
    throw error;
  });
  return loading;
}

window.classifyTag = async (text) => {
  const classifier = await loadModel();
  const best = classifier.classify(text).classifications[0].categories[0];
  return best.score >= 0.6 ? best.categoryName : 'none';
};
