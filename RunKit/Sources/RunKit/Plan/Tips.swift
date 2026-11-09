/// One or two short tips per week, shown on Today. Original copy.
public enum Tips {
    public static let byWeek: [Int: [String]] = [
        1: [
            "Go slow. If you can't talk in short sentences, ease off a little.",
            "Land softly, with your feet under you rather than out in front.",
        ],
        2: [
            "Breathe through your nose and mouth together, whatever feels easy.",
            "Rest days are when your legs get stronger. Enjoy them.",
        ],
        3: [
            "Keep your shoulders low and loose, and your hands relaxed.",
            "Have a glass of water in the hour before you run, not a big gulp at the start.",
        ],
        4: [
            "The runs get longer this week. Start each one slower than you think you need to.",
            "Short, quick steps are kinder to your knees than long strides.",
        ],
        5: [
            "Big week. Slow enough to chat is the right speed for all of it.",
            "If a run feels too hard, repeating it is part of the plan, not a step back.",
        ],
        6: [
            "Pick a flat, familiar route for the long runs.",
            "Shoes that fit well matter more than fancy ones.",
        ],
        7: [
            "You're running 25 minutes now. Think steady, not fast.",
            "A slight lean forward from the ankles helps you roll along.",
        ],
        8: [
            "Tired legs? Sleep and good food count as training too.",
            "When the middle minutes feel long, count your breaths for a while.",
        ],
        9: [
            "Last week. Run it at the same easy pace that got you here.",
            "After this, three easy 30-minute runs a week keeps it all going.",
        ],
    ]

    /// The tip for a workout: run 1 and 3 show the first tip, run 2 the second.
    public static func tip(for workout: Workout) -> String {
        let tips = byWeek[workout.week] ?? []
        guard !tips.isEmpty else { return "" }
        return tips[(workout.run - 1) % tips.count]
    }
}
