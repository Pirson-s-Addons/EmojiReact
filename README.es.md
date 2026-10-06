<h1 align="center">Emoji & React</h1>

<p align="center">
  <b>Emojis en el chat y en los bocadillos, y una rueda de reacciones para World of Warcraft: Forever</b>
</p>

<p align="center">
<a href="https://github.com/Pirson-s-Addons/EmojiReact/releases/latest">
<img src="https://img.shields.io/github/v/release/Pirson-s-Addons/EmojiReact?style=for-the-badge&color=A78BFA">
</a>
<img src="https://img.shields.io/badge/WoW_Forever-1.60.1-C4B5FD?style=for-the-badge">
<a href="LICENSE">
<img src="https://img.shields.io/badge/License-MIT-E9D5FF?style=for-the-badge">
</a>
</p>

<p align="center">
<a href="README.md">🇬🇧 English</a>
</p>

---

## Qué hace

**Emoji & React** trae los emojis de siempre al chat y a los bocadillos de WoW Forever, y añade una **rueda de reacciones**: mantén una tecla, apunta con el ratón hacia una reacción, suelta, y aparecerá encima de tu personaje para los jugadores cercanos que también tengan el addon.

| Escribes | Ves |
|---|---|
| `:joy:` `:heart_eyes:` `:thumbsup:` | el emoji, en el chat y en el bocadillo |
| `:)` `:D` `<3` `xD` | el emoji equivalente |
| un emoji pegado (Win + .) | el emoji en vez de un cuadro vacío |

## Funciones

- **Todos los emojis** (1.900 más sus tonos de piel) en el chat y en los bocadillos de /decir, /gritar y grupo, escritos como `:joy:` (códigos de Discord/Slack) o pegados.
- **Panel de emojis como el de WhatsApp** desde un botón en la caja de chat: buscador en tu idioma, categorías, recientes y tonos de piel (clic derecho en un emoji).
- **Reacciones con imágenes propias**, distintas de los emojis del chat.
- También convierte los emoticonos clásicos (`:)`, `:D`, `<3`...) sin tocar enlaces ni URLs.
- Rueda de reacciones igual que la **Ping Wheel** del propio juego: mantén **la tecla que tú elijas** (tecla, combinación o botón del ratón), apunta con el ratón hacia una reacción y suelta; soltando en la X del centro se cancela. Páginas de 4 reacciones (una por cada 4 imágenes de reacción) que cambias con la rueda del ratón, todas elegidas por ti.
- Los ajustes están en el panel del propio juego, **Opciones → AddOns**: tamaños, qué convertir, la tecla de la rueda, sus reacciones y la altura de tu propia reacción.
- Ligero, sin librerías.

## Instalación

1. Descarga el zip de la [última release](https://github.com/Pirson-s-Addons/EmojiReact/releases/latest).
2. Extrae la carpeta `EmojiReact` en `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Reinicia el juego y activa el addon.

## Uso

- `/emoji` abre los ajustes. `/emoji wheel` abre el panel de reacciones. `/emoji panel` abre el panel de emojis (también desde el botón de la caja de chat o su atajo de teclado). `/emoji key` elige la tecla de la rueda. `/emoji test` muestra una reacción encima de ti.
- **Opciones → AddOns → Emoji & React → General**: chat y bocadillos.
- **Opciones → AddOns → Emoji & React → Reacciones**: la rueda tal como se ve en el juego. Haz clic en un hueco y elige su reacción, añade o quita páginas, y ajusta la tecla, los tamaños y la altura.
- Para ver las reacciones de **los demás**, activa *Mostrar nombres de jugadores amistosos* en el mismo panel: salen encima de su placa de nombre.

## Notas

- El mensaje se sigue enviando como texto (`:joy:`): quien no tenga el addon ve el texto, como con cualquier addon de emojis.
- Blizzard no deja a los addons tocar los bocadillos ni las placas de nombre **dentro de mazmorras y bandas**: ahí los emojis solo salen en el chat y las reacciones no se ven.
- Tu personaje no tiene placa de nombre, así que tu reacción se coloca encima del centro de la pantalla. Ajusta *Altura sobre ti* a tu zoom de cámara.

---

**Autor**: Pirson · [GitHub](https://github.com/Pirson-s-Addons) · [CurseForge](https://www.curseforge.com/members/pirson/projects) · Licencia MIT · Gráficos de los emojis: [Twemoji](https://github.com/jdecked/twemoji) (CC-BY 4.0) · Datos de los emojis: [emojibase](https://emojibase.dev) (MIT)
