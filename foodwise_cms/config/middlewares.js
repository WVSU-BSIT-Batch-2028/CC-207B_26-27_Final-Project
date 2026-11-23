
module.exports = [
  'strapi::logger',
  'strapi::errors',
  'strapi::security',

  // Allow Flutter Web to access Strapi during local development.
  // WARNING: Use a restricted origin list in production.
  {
    name: 'strapi::cors',
    config: {
      origin: ['*'],
      headers: [
        'Content-Type',
        'Authorization',
        'Origin',
        'Accept',
      ],
    },
  },

  'strapi::poweredBy',
  'strapi::query',
  'strapi::body',
  'strapi::session',
  'strapi::favicon',
  'strapi::public',
];
