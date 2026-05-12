const lorem = [
  "The Wheel weaves as the Wheel wills, and this post captures it perfectly.",
  "An interesting perspective. The Pattern seems to agree with your analysis.",
  "I disagree. The Dark One's touch can be felt in this reasoning.",
  "Well written! As the Aes Sedai say, the truth you speak has the ring of it.",
  "This reminds me of the old tales the gleemen tell in the villages.",
  "Duty is heavier than a mountain, death lighter than a feather. Good post.",
  "The Prophecies of the Dragon foretold something like this, I think.",
  "Carai an Caldazar! Carai an Ellisande! Al Ellisande! A brilliant analysis.",
  "Tai'shar Malkier! This deserves more attention than it gets.",
  "The Wheel turns, and Ages come and pass, but insights like these endure.",
  "Blood and bloody ashes! I never thought of it that way before.",
  "Dovie'andi se tovya sagain. It's time to toss the dice on this idea.",
  "Kneel and swear to the Lord Dragon, or you will be knelt.",
  "The wind was not the beginning, but it was a beginning. Good start.",
  "Mat would gamble on this being right, and Mat's luck never fails.",
  "As a Wise One would say, you have much toh for not posting sooner.",
  "The Three Oaths prevent me from lying about how good this is.",
  "I sense ta'veren work in how this post came together.",
  "This is almost as confusing as navigating the Ways. Elaborate please.",
  "Perrin would approve of the straightforward honesty in this piece.",
];

const commenterNames = [
  "Rand al'Thor", "Mat Cauthon", "Perrin Aybara", "Egwene al'Vere",
  "Nynaeve al'Meara", "Elayne Trakand", "Min Farshaw", "Aviendha",
  "Thom Merrilin", "Moiraine Damodred", "Lan Mandragoran", "Loial",
  "Faile Bashere", "Siuan Sanche", "Cadsuane Melaidhrin", "Logain Ablar",
  "Gawyn Trakand", "Galad Damodred", "Berelain sur Paendrag", "Rhuarc",
  "Gaul", "Bain", "Sulin", "Amys",
  "Sorilea", "Verin Mathwin", "Sheriam Bayanar", "Alanna Mosvani",
  "Birgitte Silverbow", "Juilin Sandar",
];

module.exports = Array.from({ length: 200 }, (_, i) => ({
  id: i + 1,
  postId: (i % 150) + 1,
  body: lorem[i % lorem.length],
  authorName: commenterNames[i % commenterNames.length],
  createdAt: new Date(2025, Math.floor(i / 28), (i % 28) + 1, i % 24, (i * 7) % 60).toISOString(),
  updatedAt: new Date(2025, Math.floor(i / 28), (i % 28) + 1, i % 24, (i * 7 + 5) % 60).toISOString(),
}));
