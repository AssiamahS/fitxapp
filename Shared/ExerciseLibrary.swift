import Foundation

enum ExerciseLibrary {
    static let all: [Exercise] = [
        // Chest
        Exercise(name: "Bench Press", muscleGroup: .chest),
        Exercise(name: "Incline Bench Press", muscleGroup: .chest),
        Exercise(name: "Incline Dumbbell Press", muscleGroup: .chest),
        Exercise(name: "Dumbbell Press", muscleGroup: .chest),
        Exercise(name: "Chest Fly", muscleGroup: .chest),
        Exercise(name: "Cable Crossover", muscleGroup: .chest),
        Exercise(name: "Push Up", muscleGroup: .chest, usesWeight: false),
        Exercise(name: "Dips", muscleGroup: .chest, usesWeight: false),

        // Back
        Exercise(name: "Deadlift", muscleGroup: .back),
        Exercise(name: "Barbell Row", muscleGroup: .back),
        Exercise(name: "Dumbbell Row", muscleGroup: .back),
        Exercise(name: "Seated Cable Row", muscleGroup: .back),
        Exercise(name: "Lat Pulldown", muscleGroup: .back),
        Exercise(name: "Pull Up", muscleGroup: .back, usesWeight: false),
        Exercise(name: "Chin Up", muscleGroup: .back, usesWeight: false),
        Exercise(name: "Face Pull", muscleGroup: .back),

        // Shoulders
        Exercise(name: "Overhead Press", muscleGroup: .shoulders),
        Exercise(name: "Seated Dumbbell Press", muscleGroup: .shoulders),
        Exercise(name: "Lateral Raise", muscleGroup: .shoulders),
        Exercise(name: "Front Raise", muscleGroup: .shoulders),
        Exercise(name: "Rear Delt Fly", muscleGroup: .shoulders),
        Exercise(name: "Arnold Press", muscleGroup: .shoulders),

        // Arms
        Exercise(name: "Barbell Curl", muscleGroup: .biceps),
        Exercise(name: "Dumbbell Curl", muscleGroup: .biceps),
        Exercise(name: "Hammer Curl", muscleGroup: .biceps),
        Exercise(name: "Preacher Curl", muscleGroup: .biceps),
        Exercise(name: "Triceps Pushdown", muscleGroup: .triceps),
        Exercise(name: "Skullcrusher", muscleGroup: .triceps),
        Exercise(name: "Overhead Triceps Extension", muscleGroup: .triceps),
        Exercise(name: "Wrist Curl", muscleGroup: .forearms),

        // Legs
        Exercise(name: "Squat", muscleGroup: .quads),
        Exercise(name: "Front Squat", muscleGroup: .quads),
        Exercise(name: "Leg Press", muscleGroup: .quads),
        Exercise(name: "Leg Extension", muscleGroup: .quads),
        Exercise(name: "Lunge", muscleGroup: .quads),
        Exercise(name: "Bulgarian Split Squat", muscleGroup: .quads),
        Exercise(name: "Romanian Deadlift", muscleGroup: .hamstrings),
        Exercise(name: "Leg Curl", muscleGroup: .hamstrings),
        Exercise(name: "Hip Thrust", muscleGroup: .glutes),
        Exercise(name: "Glute Bridge", muscleGroup: .glutes, usesWeight: false),
        Exercise(name: "Standing Calf Raise", muscleGroup: .calves),
        Exercise(name: "Seated Calf Raise", muscleGroup: .calves),

        // Core
        Exercise(name: "Plank", muscleGroup: .core, usesWeight: false),
        Exercise(name: "Crunch", muscleGroup: .core, usesWeight: false),
        Exercise(name: "Leg Raise", muscleGroup: .core, usesWeight: false),
        Exercise(name: "Russian Twist", muscleGroup: .core),
        Exercise(name: "Cable Crunch", muscleGroup: .core),

        // Cardio
        Exercise(name: "Running", muscleGroup: .cardio, usesWeight: false),
        Exercise(name: "Cycling", muscleGroup: .cardio, usesWeight: false),
        Exercise(name: "Rowing Machine", muscleGroup: .cardio, usesWeight: false),
        Exercise(name: "Jump Rope", muscleGroup: .cardio, usesWeight: false),
    ]

    static func exercise(named name: String) -> Exercise {
        all.first { $0.name == name } ?? Exercise(name: name, muscleGroup: .other)
    }

    /// Seeded into the store on first launch only; editable/deletable after that.
    static var starterTemplates: [WorkoutTemplate] {
        [
            WorkoutTemplate(name: "Push Day", exercises: [
                TemplateExercise(exercise: exercise(named: "Bench Press"), plannedSets: 4),
                TemplateExercise(exercise: exercise(named: "Overhead Press"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Incline Dumbbell Press"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Lateral Raise"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Triceps Pushdown"), plannedSets: 3),
            ]),
            WorkoutTemplate(name: "Pull Day", exercises: [
                TemplateExercise(exercise: exercise(named: "Deadlift"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Pull Up"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Barbell Row"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Face Pull"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Barbell Curl"), plannedSets: 3),
            ]),
            WorkoutTemplate(name: "Leg Day", exercises: [
                TemplateExercise(exercise: exercise(named: "Squat"), plannedSets: 4),
                TemplateExercise(exercise: exercise(named: "Romanian Deadlift"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Leg Press"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Leg Curl"), plannedSets: 3),
                TemplateExercise(exercise: exercise(named: "Standing Calf Raise"), plannedSets: 4),
            ]),
        ]
    }
}
