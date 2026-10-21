import DrumCore

/// App-authored skill units on the way to Grade 8 (not copied from any book), easiest first.
public struct CurriculumUnit: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let skill: String
    public let exercises: [String]
    public let targetTempo: Int
}

public enum Grade8Curriculum {
    /// Recomputed on access so titles follow the current app language.
    public static var units: [CurriculumUnit] { [
        CurriculumUnit(id: "rudiments", title: L("Rudiment cơ bản", "Basic rudiments"), skill: L("Đánh đơn, đánh kép, paradiddle, flam, cuộn", "Singles, doubles, paradiddles, flams, rolls"), exercises: [
            "title: Đánh đơn móc kép (Single Stroke)\ntitle_en: Single strokes, 16ths\ntime: 4/4\ntempo: 60-110\ngrid: 4\nSN: xxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRL",
            "title: Đánh kép móc kép (Double Stroke)\ntitle_en: Double strokes, 16ths\ntime: 4/4\ntempo: 50-100\ngrid: 4\nSN: xxxxxxxxxxxxxxxx\nST: RRLLRRLLRRLLRRLL",
            "title: Paradiddle có nhấn (accent)\ntitle_en: Accented paradiddle\ntime: 4/4\ntempo: 50-100\ngrid: 4\nSN: XxxxXxxxXxxxXxxx\nST: RLRRLRLLRLRRLRLL",
            "title: Paradiddle đôi, chùm ba (Double Paradiddle)\ntitle_en: Double paradiddle (triplets)\ntime: 4/4\ntempo: 50-90\ngrid: 3\nSN: XxxxxxXxxxxx\nST: RLRLRRLRLRLL",
            "title: Flam nốt đen (Flam)\ntitle_en: Quarter-note flams\ntime: 4/4\ntempo: 50-90\ngrid: 1\nSN: ffff\nST: RLRL",
            "title: Cuộn 5 nét (Five Stroke Roll)\ntitle_en: Five stroke roll\ntime: 4/4\ntempo: 50-80\ngrid: 4\nSN: xxxxX---xxxxX---\nST: RRLLR---LLRRL---",
        ], targetTempo: 100),
        CurriculumUnit(id: "groove16", title: L("Groove móc đơn & móc kép, nốt ma", "8th & 16th grooves, ghost notes"), skill: L("Groove", "Grooves"), exercises: [
            "title: Groove rock móc đơn, kick móc kép\ntitle_en: Rock 8ths with 16th kicks\ntime: 4/4\ntempo: 60-110\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: ----X-------X---\nBD: x-----x-x-x-----",
            "title: Groove có nốt ma (ghost note)\ntitle_en: Ghost note groove\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: --g-X-g---g-X--g\nBD: x-----x---x-----",
            "title: Hi-hat móc kép\ntitle_en: 16th-note hi-hat\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: xxxxxxxxxxxxxxxx\nSN: ----X-------X---\nBD: x--x--x-x-------",
            "title: Hi-hat mở (open hi-hat)\ntitle_en: Open hi-hat groove\ntime: 4/4\ntempo: 60-110\ngrid: 4\nHH: x-x-x-x-x-x-x---\nOH: --------------x-\nSN: ----X-------X---\nBD: x-----x-x-------",
        ], targetTempo: 110),
        CurriculumUnit(id: "linear", title: L("Groove & fill linear", "Linear grooves & fills"), skill: L("Linear", "Linear"), exercises: [
            "title: Linear tay–chân (không trùng nốt)\ntitle_en: Linear hands & feet\ntime: 4/4\ntempo: 60-100\ngrid: 4\nSN: -xx--xx--xx--xx-\nBD: x--xx--xx--xx--x\nST: FRLFFRLFFRLFFRLF",
            "title: Linear hi-hat / bass / snare\ntitle_en: Linear hi-hat / bass / snare\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: x---x---x---x---\nSN: --X---X---X---X-\nBD: -x---x---x---x--",
            "title: Fill linear quanh tom\ntitle_en: Linear tom fill\ntime: 4/4\ntempo: 60-100\ngrid: 4\nSN: xx--------------\nT1: --xx------------\nT2: ----xx----------\nFT: ------xx--------\nBD: --------x-------\nCR: --------x-------",
        ], targetTempo: 100),
        CurriculumUnit(id: "feet", title: L("Phối hợp chân", "Foot coordination"), skill: L("Kick liên tục, hi-hat chân", "Kick ostinato, hi-hat foot"), exercises: [
            "title: Kick móc đơn liên tục (ostinato)\ntitle_en: 8th-note kick ostinato\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: ----X-------X---\nBD: x-x-x-x-x-x-x-x-",
            "title: Kick đôi móc kép\ntitle_en: 16th-note double kicks\ntime: 4/4\ntempo: 60-90\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: ----X-------X---\nBD: xx----xx-xx-----",
            "title: Hi-hat chân + snare móc đơn\ntitle_en: Hi-hat foot + 8th-note snare\ntime: 4/4\ntempo: 50-90\ngrid: 2\nSN: xxxxxxxx\nHP: x-x-x-x-\nST: RLRLRLRL",
        ], targetTempo: 100),
        CurriculumUnit(id: "triplets", title: L("Chùm ba, shuffle, chùm sáu", "Triplets, shuffle, sextuplets"), skill: L("Chùm ba", "Triplets"), exercises: [
            "title: Đánh đơn chùm ba (Triplet)\ntitle_en: Triplet single strokes\ntime: 4/4\ntempo: 50-100\ngrid: 3\nSN: xxxxxxxxxxxx\nST: RLRLRLRLRLRL",
            "title: Nhịp shuffle\ntitle_en: Shuffle\ntime: 4/4\ntempo: 60-110\ngrid: 3\nHH: x-xx-xx-xx-x\nSN: ---X-----X--\nBD: x-----x-----",
            "title: Shuffle nửa nhịp (Half-time Shuffle)\ntitle_en: Half-time shuffle\ntime: 4/4\ntempo: 60-100\ngrid: 3\nHH: x-xx-xx-xx-x\nSN: -g--g-X-g--g\nBD: x-------x---",
            "title: Đánh đơn chùm sáu (Sextuplet)\ntitle_en: Sextuplet single strokes\ntime: 4/4\ntempo: 50-80\ngrid: 6\nSN: xxxxxxxxxxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRLRLRLRLRL",
        ], targetTempo: 100),
        CurriculumUnit(id: "oddtime", title: L("Nhịp lẻ 7/8, 5/4, 12/8", "Odd time 7/8, 5/4, 12/8"), skill: L("Nhịp lẻ", "Odd time"), exercises: [
            "title: Groove nhịp 7/8\ntitle_en: 7/8 groove\ntime: 7/8\ntempo: 60-100\ngrid: 1\nHH: xxxxxxx\nSN: --X--X-\nBD: x--x---",
            "title: Groove nhịp 5/4\ntitle_en: 5/4 groove\ntime: 5/4\ntempo: 60-100\ngrid: 2\nHH: xxxxxxxxxx\nSN: --X---X---\nBD: x---x---x-",
            "title: Groove nhịp 12/8\ntitle_en: 12/8 groove\ntime: 12/8\ntempo: 50-80\ngrid: 1\nHH: xxxxxxxxxxxx\nSN: ---X-----X--\nBD: x-----x-----",
        ], targetTempo: 100),
        CurriculumUnit(id: "fills", title: L("Fill & dời phách", "Fills & displacement"), skill: L("Fill", "Fills"), exercises: [
            "title: Fill móc kép quanh tom\ntitle_en: 16th-note tom fill\ntime: 4/4\ntempo: 60-100\ngrid: 4\nSN: xxxx------------\nT1: ----xxxx--------\nT2: --------xxxx----\nFT: ------------xxxx\nST: RLRLRLRLRLRLRLRL",
            "title: Fill chùm ba\ntitle_en: Triplet fill\ntime: 4/4\ntempo: 60-100\ngrid: 3\nSN: Xxx---------\nT1: ---Xxx------\nT2: ------Xxx---\nFT: ---------Xxx\nST: RLLRLLRLLRLL",
            "title: Dời phách snare (displacement)\ntitle_en: Displaced backbeat\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: -----X------X---\nBD: x-----x-x-------",
        ], targetTempo: 110),
        CurriculumUnit(id: "reading", title: L("Đọc nhạc", "Reading"), skill: L("Đọc nhạc", "Sight reading"), exercises: [
            "title: Đọc nhạc móc đơn có dấu lặng\ntitle_en: Reading: 8ths with rests\ntime: 4/4\ntempo: 60-90\ngrid: 2\nSN: x-x-xx-x|x---x-x-|xx--x-x-|x-x-x---",
            "title: Đọc nhạc móc kép\ntitle_en: Reading: 16ths\ntime: 4/4\ntempo: 60-90\ngrid: 4\nSN: x-x-xxxxx---x-x-|x---xx-xx-x-x---",
            "title: Đọc nhạc chùm ba\ntitle_en: Reading: triplets\ntime: 4/4\ntempo: 60-90\ngrid: 3\nSN: xxx-x-x--xxx|x--xxx-x-x--",
        ], targetTempo: 90),
    ] }
}
