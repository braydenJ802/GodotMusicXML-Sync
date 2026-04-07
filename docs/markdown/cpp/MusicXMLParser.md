# MusicXMLParser

**Inherits:** `RefCounted`

## Brief Description
Parses raw MusicXML text into structured runtime song data.

## Description
`MusicXMLParser` reads uncompressed MusicXML text and extracts musical timing and structure into a `SongData` resource. It collects tempo changes, time signatures, cue markers, and measure boundaries, computes precise measure offsets, and stores per-measure beat counts.

It also supports basic smoothing of continuous tempo ramps such as accelerando and ritardando.

## Methods

### `parse_text(xml_text: String) -> SongData`
Parses a string of MusicXML content and returns a populated `SongData` resource.

The parser extracts tempo, time signature, cue, and measure timing information needed for runtime synchronization and transitions.