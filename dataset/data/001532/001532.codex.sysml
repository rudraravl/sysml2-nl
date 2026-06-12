package PopMusicAutomationModel {

  import ScalarValues::*;
  import SI::*;

  attribute def BeatsPerMinute :> Real;
  attribute def DecibelLevel :> Real;
  attribute def Percent :> Real;
  attribute def Seconds :> Real;
  attribute def Hertz :> Real;
  attribute def Confidence :> Real;
  attribute def MusicalKey :> String;
  attribute def LyricText :> String;
  attribute def GenreLabel :> String;

  item def AudioStem {
    attribute name : String;
    attribute duration : Seconds;
    attribute sampleRate : Hertz;
    attribute loudness : DecibelLevel;
  }

  item def VocalStem :> AudioStem {
    attribute leadVocalPresent : Boolean;
    attribute lyricLanguage : String;
  }

  item def InstrumentStem :> AudioStem {
    attribute instrumentFamily : String;
  }

  item def LyricDraft {
    attribute text : LyricText;
    attribute theme : String;
    attribute syllableDensity : Real;
    attribute explicitContentScore : Percent;
  }

  item def MelodyLine {
    attribute key : MusicalKey;
    attribute averagePitch : Hertz;
    attribute hookStrength : Percent;
    attribute noteCount : Integer;
  }

  item def ChordProgression {
    attribute key : MusicalKey;
    attribute progressionName : String;
    attribute harmonicTension : Percent;
  }

  item def MixPlan {
    attribute targetLoudness : DecibelLevel;
    attribute vocalLevel : DecibelLevel;
    attribute bassLevel : DecibelLevel;
    attribute stereoWidth : Percent;
    attribute compressionRatio : Real;
  }

  item def PopSong {
    attribute title : String;
    attribute tempo : BeatsPerMinute;
    attribute key : MusicalKey;
    attribute duration : Seconds;
    attribute genre : GenreLabel;
    attribute danceability : Percent;
    attribute radioReadiness : Percent;
  }

  item def ListenerProfile {
    attribute targetAgeRange : String;
    attribute preferredTempoMin : BeatsPerMinute;
    attribute preferredTempoMax : BeatsPerMinute;
    attribute preferredMood : String;
    attribute marketRegion : String;
  }

  item def PerformanceReport {
    attribute hookScore : Percent;
    attribute lyricFitScore : Percent;
    attribute mixQualityScore : Percent;
    attribute predictedStreamingScore : Percent;
    attribute approvalConfidence : Confidence;
  }

  port def AudioInputPort {
    in item rawStem : AudioStem;
  }

  port def AudioOutputPort {
    out item finishedSong : PopSong;
  }

  port def LyricPort {
    out item lyricDraft : LyricDraft;
  }

  port def MelodyPort {
    out item melodyLine : MelodyLine;
  }

  port def HarmonyPort {
    out item chordProgression : ChordProgression;
  }

  port def MixControlPort {
    in item mixPlan : MixPlan;
  }

  port def AnalysisPort {
    out item performanceReport : PerformanceReport;
  }

  port def ProfilePort {
    in item listenerProfile : ListenerProfile;
  }

  action def GenerateLyrics {
    in item profile : ListenerProfile;
    out item lyrics : LyricDraft;
  }

  action def ComposeHookMelody {
    in item lyrics : LyricDraft;
    in item profile : ListenerProfile;
    out item melody : MelodyLine;
  }

  action def BuildChordProgression {
    in item melody : MelodyLine;
    out item harmony : ChordProgression;
  }

  action def ArrangeInstrumental {
    in item harmony : ChordProgression;
    in item melody : MelodyLine;
    out item drums : InstrumentStem;
    out item bass : InstrumentStem;
    out item synths : InstrumentStem;
  }

  action def SynthesizeVocals {
    in item lyrics : LyricDraft;
    in item melody : MelodyLine;
    out item vocal : VocalStem;
  }

  action def MixAndMaster {
    in item vocal : VocalStem;
    in item drums : InstrumentStem;
    in item bass : InstrumentStem;
    in item synths : InstrumentStem;
    in item plan : MixPlan;
    out item song : PopSong;
  }

  action def EvaluatePopReadiness {
    in item song : PopSong;
    in item profile : ListenerProfile;
    out item report : PerformanceReport;
  }

  action def ProducePopSong {
    in item profile : ListenerProfile;
    in item plan : MixPlan;
    out item song : PopSong;
    out item report : PerformanceReport;

    action generateLyrics : GenerateLyrics {
      in profile = ProducePopSong::profile;
    }

    action composeHook : ComposeHookMelody {
      in lyrics = generateLyrics.lyrics;
      in profile = ProducePopSong::profile;
    }

    action buildHarmony : BuildChordProgression {
      in melody = composeHook.melody;
    }

    action arrange : ArrangeInstrumental {
      in harmony = buildHarmony.harmony;
      in melody = composeHook.melody;
    }

    action synthesizeVocals : SynthesizeVocals {
      in lyrics = generateLyrics.lyrics;
      in melody = composeHook.melody;
    }

    action mixMaster : MixAndMaster {
      in vocal = synthesizeVocals.vocal;
      in drums = arrange.drums;
      in bass = arrange.bass;
      in synths = arrange.synths;
      in plan = ProducePopSong::plan;
    }

    action evaluate : EvaluatePopReadiness {
      in song = mixMaster.song;
      in profile = ProducePopSong::profile;
    }

    bind song = mixMaster.song;
    bind report = evaluate.report;
  }

  state def ProductionStateMachine {
    state idle;
    state profiling;
    state songwriting;
    state arranging;
    state vocalSynthesis;
    state mixing;
    state evaluating;
    state publishingReady;
    state revisionRequired;

    transition first idle then profiling;
    transition profiling then songwriting;
    transition songwriting then arranging;
    transition arranging then vocalSynthesis;
    transition vocalSynthesis then mixing;
    transition mixing then evaluating;
    transition evaluating then publishingReady
      if approvalConfidence >= 0.85;
    transition evaluating then revisionRequired
      if approvalConfidence < 0.85;
    transition revisionRequired then songwriting;
  }

  part def LyricGenerator {
    port profileIn : ProfilePort;
    port lyricsOut : LyricPort;

    attribute supportedThemes : String = "romance, confidence, nightlife, heartbreak, celebration";
    attribute maxExplicitContentScore : Percent = 15.0;

    perform action generateLyrics : GenerateLyrics;
  }

  part def MelodyComposer {
    port profileIn : ProfilePort;
    port lyricsIn : LyricPort;
    port melodyOut : MelodyPort;

    attribute targetHookStrength : Percent = 82.0;
    attribute minTempo : BeatsPerMinute = 92.0;
    attribute maxTempo : BeatsPerMinute = 128.0;

    perform action composeHook : ComposeHookMelody;
  }

  part def HarmonyEngine {
    port melodyIn : MelodyPort;
    port harmonyOut : HarmonyPort;

    attribute allowedProgressions : String = "I-V-vi-IV, vi-IV-I-V, I-vi-IV-V, ii-V-I";
    attribute maxHarmonicTension : Percent = 65.0;

    perform action buildHarmony : BuildChordProgression;
  }

  part def ArrangementEngine {
    port melodyIn : MelodyPort;
    port harmonyIn : HarmonyPort;
    port drumsOut : AudioOutputPort;
    port bassOut : AudioOutputPort;
    port synthsOut : AudioOutputPort;

    attribute drumStyle : String = "four-on-the-floor with syncopated claps";
    attribute bassStyle : String = "side-chained synth bass";
    attribute synthLayerCount : Integer = 6;

    perform action arrangeInstrumental : ArrangeInstrumental;
  }

  part def VocalSynthesizer {
    port lyricsIn : LyricPort;
    port melodyIn : MelodyPort;
    port vocalOut : AudioOutputPort;

    attribute vocalCharacter : String = "bright contemporary pop lead";
    attribute harmonyVoiceCount : Integer = 4;
    attribute pitchCorrectionStrength : Percent = 72.0;

    perform action synthesizeVocals : SynthesizeVocals;
  }

  part def MixingMasteringUnit {
    port mixControlIn : MixControlPort;
    port vocalIn : AudioInputPort;
    port drumsIn : AudioInputPort;
    port bassIn : AudioInputPort;
    port synthsIn : AudioInputPort;
    port songOut : AudioOutputPort;

    attribute targetIntegratedLoudness : DecibelLevel = -9.0;
    attribute truePeakLimit : DecibelLevel = -1.0;
    attribute masterBusCompressionRatio : Real = 2.5;

    perform action mixAndMaster : MixAndMaster;
  }

  part def MarketEvaluator {
    port profileIn : ProfilePort;
    port songIn : AudioInputPort;
    port analysisOut : AnalysisPort;

    attribute minimumHookScore : Percent = 80.0;
    attribute minimumMixQualityScore : Percent = 85.0;
    attribute minimumPredictedStreamingScore : Percent = 75.0;

    perform action evaluateReadiness : EvaluatePopReadiness;
  }

  part def PopMusicAutomationSystem {
    doc /* Primary function: automatically generate, arrange, synthesize, mix, master, and evaluate a market-ready pop song from a listener profile and production constraints. */

    port profileInput : ProfilePort;
    port mixPlanInput : MixControlPort;
    port finishedSongOutput : AudioOutputPort;
    port performanceOutput : AnalysisPort;

    part lyricGenerator : LyricGenerator;
    part melodyComposer : MelodyComposer;
    part harmonyEngine : HarmonyEngine;
    part arrangementEngine : ArrangementEngine;
    part vocalSynthesizer : VocalSynthesizer;
    part mixingMasteringUnit : MixingMasteringUnit;
    part marketEvaluator : MarketEvaluator;

    attribute nominalTempo : BeatsPerMinute = 116.0;
    attribute nominalSongDuration : Seconds = 192.0;
    attribute primaryGenre : GenreLabel = "Pop";
    attribute automationMode : String = "radio single production";

    exhibit state productionLifecycle : ProductionStateMachine;

    perform action produceSong : ProducePopSong;

    connect profileInput to lyricGenerator.profileIn;
    connect profileInput to melodyComposer.profileIn;
    connect profileInput to marketEvaluator.profileIn;

    connect lyricGenerator.lyricsOut to melodyComposer.lyricsIn;
    connect lyricGenerator.lyricsOut to vocalSynthesizer.lyricsIn;

    connect melodyComposer.melodyOut to harmonyEngine.melodyIn;
    connect melodyComposer.melodyOut to arrangementEngine.melodyIn;
    connect melodyComposer.melodyOut to vocalSynthesizer.melodyIn;

    connect harmonyEngine.harmonyOut to arrangementEngine.harmonyIn;

    connect mixPlanInput to mixingMasteringUnit.mixControlIn;

    connect vocalSynthesizer.vocalOut to mixingMasteringUnit.vocalIn;
    connect arrangementEngine.drumsOut to mixingMasteringUnit.drumsIn;
    connect arrangementEngine.bassOut to mixingMasteringUnit.bassIn;
    connect arrangementEngine.synthsOut to mixingMasteringUnit.synthsIn;

    connect mixingMasteringUnit.songOut to finishedSongOutput;
    connect mixingMasteringUnit.songOut to marketEvaluator.songIn;
    connect marketEvaluator.analysisOut to performanceOutput;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : PopMusicAutomationSystem;

    require constraint {
      system.primaryGenre == "Pop"
    }

    doc /* The system shall produce a complete pop song by automating lyric generation, hook composition, harmonic progression, instrumental arrangement, vocal synthesis, mixing, mastering, and market-readiness evaluation. */
  }

  requirement def TempoRequirement {
    subject song : PopSong;

    require constraint {
      song.tempo >= 92.0 and song.tempo <= 128.0
    }

    doc /* Produced songs shall remain within a contemporary pop tempo range suitable for streaming and radio playlists. */
  }

  requirement def DurationRequirement {
    subject song : PopSong;

    require constraint {
      song.duration >= 150.0 and song.duration <= 225.0
    }

    doc /* Produced songs shall have a duration compatible with common pop single formats. */
  }

  requirement def HookQualityRequirement {
    subject report : PerformanceReport;

    require constraint {
      report.hookScore >= 80.0
    }

    doc /* The generated song shall include a memorable hook with a predicted hook score of at least 80 percent. */
  }

  requirement def MixQualityRequirement {
    subject report : PerformanceReport;

    require constraint {
      report.mixQualityScore >= 85.0
    }

    doc /* The mastered song shall meet a minimum mix quality score of 85 percent. */
  }

  requirement def ReadinessRequirement {
    subject report : PerformanceReport;

    require constraint {
      report.approvalConfidence >= 0.85
    }

    doc /* The automation workflow shall approve a song for publishing only when the evaluation confidence is at least 0.85. */
  }

  requirement def ContentSafetyRequirement {
    subject lyrics : LyricDraft;

    require constraint {
      lyrics.explicitContentScore <= 15.0
    }

    doc /* Generated lyrics shall keep explicit content below the configured threshold for mainstream pop distribution. */
  }

  satisfy PrimaryFunctionRequirement by PopMusicAutomationSystem;
  satisfy TempoRequirement by PopMusicAutomationSystem::produceSong;
  satisfy DurationRequirement by PopMusicAutomationSystem::produceSong;
  satisfy HookQualityRequirement by MarketEvaluator;
  satisfy MixQualityRequirement by MixingMasteringUnit;
  satisfy ReadinessRequirement by MarketEvaluator;
  satisfy ContentSafetyRequirement by LyricGenerator;
}