// Browser file operations for schedule imports. Documents stay on this origin.
(() => {
  const asset = name => new URL('schedule_ocr/' + name, document.baseURI).href;
  const cacheName = 'wayfinder-schedule-files-v1';
  const fileKey = id => new URL('schedule-files/' + encodeURIComponent(id), document.baseURI).href;

  window.wayfinderSchedule = {
    async put(id, bytes) {
      const cache = await caches.open(cacheName);
      await cache.put(fileKey(id), new Response(bytes));
    },
    async get(id) {
      const response = await (await caches.open(cacheName)).match(fileKey(id));
      if (!response) throw new Error('Saved file unavailable');
      return new Uint8Array(await response.arrayBuffer());
    },
    async remove(id) {
      await (await caches.open(cacheName)).delete(fileKey(id));
    },
    async recognize(bytes) {
      const bitmap = await createImageBitmap(new Blob([bytes]));
      const canvas = document.createElement('canvas');
      try {
        const scale = Math.min(1, 3500 / Math.max(bitmap.width, bitmap.height));
        canvas.width = Math.max(1, Math.round(bitmap.width * scale));
        canvas.height = Math.max(1, Math.round(bitmap.height * scale));
        const context = canvas.getContext('2d');
        context.fillStyle = 'white';
        context.fillRect(0, 0, canvas.width, canvas.height);
        context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      } finally {
        bitmap.close();
      }
      const {createWorker} = await import(asset('tesseract.esm.min.js')).then(m => m.default);
      const worker = await createWorker('eng', 1, {
        workerPath: asset('worker.min.js'),
        corePath: asset('tesseract-core-lstm.wasm.js'),
        langPath: asset(''),
        workerBlobURL: false,
      });
      try {
        const {data} = await worker.recognize(canvas, {}, {text: true, blocks: true});
        const lines = [], words = [];
        const piece = ({text, bbox}) => [text, bbox.x0, bbox.y0, bbox.x1, bbox.y1];
        for (const block of data.blocks || []) {
          for (const paragraph of block.paragraphs) {
            for (const line of paragraph.lines) {
              lines.push(piece(line));
              words.push(...line.words.map(piece));
            }
          }
        }
        return JSON.stringify({text: data.text, lines, words});
      } finally {
        await worker.terminate();
      }
    }
  };
})();
