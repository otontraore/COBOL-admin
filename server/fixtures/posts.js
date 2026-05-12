const lorem = [
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.",
  "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident.",
  "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis.",
  "Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.",
  "Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt.",
  "Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur.",
  "Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat.",
  "At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores.",
  "Et harum quidem rerum facilis est et expedita distinctio. Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil impedit.",
  "Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet ut et voluptates repudiandae sint et molestiae.",
];

const titles = [
  "The Prophecies of the Dragon", "Whispers in the White Tower",
  "A Journey Through the Ways", "The Fall of Shadar Logoth",
  "Secrets of the Forsaken", "Tales from the Two Rivers",
  "The Hunt for the Horn", "Aiel Customs and Traditions",
  "The Art of Channeling Saidin", "Daughters of the Night",
  "The Seanchan Invasion", "Life Among the Ogier",
  "The Black Tower Rises", "Dreams in Tel'aran'rhiod",
  "The Last Days of Artur Hawkwing", "Warder Training Grounds",
  "The Breaking of the World", "Min's Viewings Explained",
  "Travels with a Gleeman", "The Stone of Tear Falls",
  "Callandor and Its Purpose", "The Amyrlin's Anger",
  "Wolves of the Wild", "The Great Hunt Begins",
  "Battles of the Blight", "The Flame and the Void",
  "Darkfriends Among Us", "The Kin of Ebou Dar",
  "Sailing the Aryth Ocean", "The Price of the Oath Rod",
  "Tigraine's Secret Journey", "The Horn of Valere Sounds",
  "Wise Ones of the Waste", "The Treekiller's Lament",
  "Mat's Impossible Luck", "Portal Stones and Other Worlds",
  "The Age of Legends Remembered", "Tarmon Gai'don Approaches",
  "The Dragon Reborn Walks", "A Crown of Swords",
  "Crossroads at Twilight", "The Path of Daggers",
  "Winter's Heart Frozen", "Knife of Dreams Unsheathed",
  "The Gathering Storm Breaks", "Towers of Midnight Rise",
  "A Memory of Light Fades", "The Eye of the World Opens",
  "The Shadow Rising", "Fires of Heaven Burning",
];

const numAuthors = 100;
const numTags = 101;

module.exports = Array.from({ length: 150 }, (_, i) => ({
  id: i + 1,
  title: titles[i % titles.length] + (i >= titles.length ? ` (Part ${Math.floor(i / titles.length) + 1})` : ""),
  body: lorem[i % lorem.length],
  authorId: (i % numAuthors) + 4,
  tagIds: [
    (i % numTags) + 1,
    ((i * 3 + 7) % numTags) + 1,
  ],
  createdAt: new Date(2025, Math.floor(i / 28), (i % 28) + 1).toISOString(),
  updatedAt: new Date(2025, Math.floor(i / 28), (i % 28) + 1, 12).toISOString(),
}));
