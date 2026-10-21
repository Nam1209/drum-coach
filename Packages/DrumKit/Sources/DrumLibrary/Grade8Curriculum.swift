/// App-authored skill units on the way to Grade 8 (not copied from any book), easiest first.
public struct CurriculumUnit: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let skill: String
    public let exercises: [String]
    public let targetTempo: Int
}

public enum Grade8Curriculum {
    public static let units: [CurriculumUnit] = [
        CurriculumUnit(id: "rudiments", title: "Rudiments cơ bản", skill: "Single/double stroke, paradiddle, flam, roll", exercises: [
            "title: Single Stroke 16th\ntime: 4/4\ntempo: 60-110\ngrid: 4\nSN: xxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRL",
            "title: Double Stroke 16th\ntime: 4/4\ntempo: 50-100\ngrid: 4\nSN: xxxxxxxxxxxxxxxx\nST: RRLLRRLLRRLLRRLL",
            "title: Paradiddle có accent\ntime: 4/4\ntempo: 50-100\ngrid: 4\nSN: XxxxXxxxXxxxXxxx\nST: RLRRLRLLRLRRLRLL",
            "title: Double Paradiddle (chùm ba)\ntime: 4/4\ntempo: 50-90\ngrid: 3\nSN: XxxxxxXxxxxx\nST: RLRLRRLRLRLL",
            "title: Flam nốt đen\ntime: 4/4\ntempo: 50-90\ngrid: 1\nSN: ffff\nST: RLRL",
            "title: Five Stroke Roll\ntime: 4/4\ntempo: 50-80\ngrid: 4\nSN: xxxxX---xxxxX---\nST: RRLLR---LLRRL---",
        ], targetTempo: 100),
        CurriculumUnit(id: "groove16", title: "Groove 8th & 16th, ghost note", skill: "Groove", exercises: [
            "title: Rock 8th, kick 16th\ntime: 4/4\ntempo: 60-110\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: ----X-------X---\nBD: x-----x-x-x-----",
            "title: Ghost note groove\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: --g-X-g---g-X--g\nBD: x-----x---x-----",
            "title: Hi-hat 16th\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: xxxxxxxxxxxxxxxx\nSN: ----X-------X---\nBD: x--x--x-x-------",
            "title: Open hi-hat\ntime: 4/4\ntempo: 60-110\ngrid: 4\nHH: x-x-x-x-x-x-x---\nOH: --------------x-\nSN: ----X-------X---\nBD: x-----x-x-------",
        ], targetTempo: 110),
        CurriculumUnit(id: "linear", title: "Linear groove & fill", skill: "Linear", exercises: [
            "title: Linear tay–chân\ntime: 4/4\ntempo: 60-100\ngrid: 4\nSN: -xx--xx--xx--xx-\nBD: x--xx--xx--xx--x\nST: FRLFFRLFFRLFFRLF",
            "title: Linear HH/BD/SN\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: x---x---x---x---\nSN: --X---X---X---X-\nBD: -x---x---x---x--",
            "title: Linear fill quanh tom\ntime: 4/4\ntempo: 60-100\ngrid: 4\nSN: xx--------------\nT1: --xx------------\nT2: ----xx----------\nFT: ------xx--------\nBD: --------x-------\nCR: --------x-------",
        ], targetTempo: 100),
        CurriculumUnit(id: "feet", title: "Phối hợp chân", skill: "Kick ostinato, hi-hat chân", exercises: [
            "title: Kick 8th ostinato\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: ----X-------X---\nBD: x-x-x-x-x-x-x-x-",
            "title: Kick đôi 16th\ntime: 4/4\ntempo: 60-90\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: ----X-------X---\nBD: xx----xx-xx-----",
            "title: Hi-hat chân + snare 8th\ntime: 4/4\ntempo: 50-90\ngrid: 2\nSN: xxxxxxxx\nHP: x-x-x-x-\nST: RLRLRLRL",
        ], targetTempo: 100),
        CurriculumUnit(id: "triplets", title: "Chùm ba, shuffle, sextuplet", skill: "Triplets", exercises: [
            "title: Triplet single stroke\ntime: 4/4\ntempo: 50-100\ngrid: 3\nSN: xxxxxxxxxxxx\nST: RLRLRLRLRLRL",
            "title: Shuffle\ntime: 4/4\ntempo: 60-110\ngrid: 3\nHH: x-xx-xx-xx-x\nSN: ---X-----X--\nBD: x-----x-----",
            "title: Half-time shuffle\ntime: 4/4\ntempo: 60-100\ngrid: 3\nHH: x-xx-xx-xx-x\nSN: -g--g-X-g--g\nBD: x-------x---",
            "title: Sextuplet single stroke\ntime: 4/4\ntempo: 50-80\ngrid: 6\nSN: xxxxxxxxxxxxxxxxxxxxxxxx\nST: RLRLRLRLRLRLRLRLRLRLRLRL",
        ], targetTempo: 100),
        CurriculumUnit(id: "oddtime", title: "Nhịp lẻ 7/8, 5/4, 12/8", skill: "Odd time", exercises: [
            "title: Groove 7/8\ntime: 7/8\ntempo: 60-100\ngrid: 1\nHH: xxxxxxx\nSN: --X--X-\nBD: x--x---",
            "title: Groove 5/4\ntime: 5/4\ntempo: 60-100\ngrid: 2\nHH: xxxxxxxxxx\nSN: --X---X---\nBD: x---x---x-",
            "title: Groove 12/8\ntime: 12/8\ntempo: 50-80\ngrid: 1\nHH: xxxxxxxxxxxx\nSN: ---X-----X--\nBD: x-----x-----",
        ], targetTempo: 100),
        CurriculumUnit(id: "fills", title: "Fill & displacement", skill: "Fills", exercises: [
            "title: Fill 16th quanh tom\ntime: 4/4\ntempo: 60-100\ngrid: 4\nSN: xxxx------------\nT1: ----xxxx--------\nT2: --------xxxx----\nFT: ------------xxxx\nST: RLRLRLRLRLRLRLRL",
            "title: Fill chùm ba\ntime: 4/4\ntempo: 60-100\ngrid: 3\nSN: Xxx---------\nT1: ---Xxx------\nT2: ------Xxx---\nFT: ---------Xxx\nST: RLLRLLRLLRLL",
            "title: Backbeat lệch (displacement)\ntime: 4/4\ntempo: 60-100\ngrid: 4\nHH: x-x-x-x-x-x-x-x-\nSN: -----X------X---\nBD: x-----x-x-------",
        ], targetTempo: 110),
        CurriculumUnit(id: "reading", title: "Đọc nhạc", skill: "Sight reading", exercises: [
            "title: Đọc 8th có lặng\ntime: 4/4\ntempo: 60-90\ngrid: 2\nSN: x-x-xx-x|x---x-x-|xx--x-x-|x-x-x---",
            "title: Đọc 16th\ntime: 4/4\ntempo: 60-90\ngrid: 4\nSN: x-x-xxxxx---x-x-|x---xx-xx-x-x---",
            "title: Đọc chùm ba\ntime: 4/4\ntempo: 60-90\ngrid: 3\nSN: xxx-x-x--xxx|x--xxx-x-x--",
        ], targetTempo: 90),
    ]
}
