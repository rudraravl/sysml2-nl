package FisheriesAcousticsSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Frequency :> Real {
    unit = "kHz";
  }

  attribute def SoundPressureLevel :> Real {
    unit = "dB re 1 uPa";
  }

  attribute def Range :> Real {
    unit = "m";
  }

  attribute def Depth :> Real {
    unit = "m";
  }

  attribute def Speed :> Real {
    unit = "m/s";
  }

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def Salinity :> Real {
    unit = "PSU";
  }

  attribute def TimeDuration :> Real {
    unit = "s";
  }

  attribute def BiomassDensity :> Real {
    unit = "kg/m^3";
  }

  attribute def TargetStrength :> Real {
    unit = "dB";
  }

  attribute def Position {
    attribute latitude : Real;
    attribute longitude : Real;
    attribute depth : Depth;
  }

  item def AcousticPulse {
    attribute centerFrequency : Frequency;
    attribute bandwidth : Frequency;
    attribute sourceLevel : SoundPressureLevel;
    attribute pulseLength : TimeDuration;
    attribute pingId : Integer;
  }

  item def AcousticEcho {
    attribute pingId : Integer;
    attribute receivedLevel : SoundPressureLevel;
    attribute targetStrength : TargetStrength;
    attribute range : Range;
    attribute depth : Depth;
    attribute timestamp : Real;
  }

  item def WaterColumnProfile {
    attribute temperature : Temperature;
    attribute salinity : Salinity;
    attribute soundSpeed : Speed;
    attribute sampledDepth : Depth;
  }

  item def NavigationFix {
    attribute vesselPosition : Position;
    attribute vesselSpeed : Speed;
    attribute headingDeg : Real;
    attribute timestamp : Real;
  }

  item def BiomassEstimate {
    attribute surveyCellId : Integer;
    attribute meanDepth : Depth;
    attribute nauticalAreaScatteringCoefficient : Real;
    attribute biomassDensity : BiomassDensity;
    attribute confidence : Real;
  }

  port def AcousticTransmitPort {
    out item pulse : AcousticPulse;
  }

  port def AcousticReceivePort {
    in item echo : AcousticEcho;
  }

  port def DataOutPort {
    out item estimate : BiomassEstimate;
  }

  port def DataInPort {
    in item nav : NavigationFix;
    in item profile : WaterColumnProfile;
  }

  port def PowerPort {
    in attribute voltage : Real;
    in attribute current : Real;
  }

  action def EmitPing {
    in attribute frequency : Frequency;
    in attribute pulseLength : TimeDuration;
    out item pulse : AcousticPulse;
  }

  action def ReceiveEchoes {
    in item pulse : AcousticPulse;
    out item echo : AcousticEcho;
  }

  action def CorrectForEnvironment {
    in item rawEcho : AcousticEcho;
    in item profile : WaterColumnProfile;
    out item correctedEcho : AcousticEcho;
  }

  action def EstimateFishBiomass {
    in item correctedEcho : AcousticEcho;
    in item nav : NavigationFix;
    out item estimate : BiomassEstimate;
  }

  action def StoreSurveyRecord {
    in item estimate : BiomassEstimate;
  }

  state def SurveyOperatingState {
    state idle;
    state calibrating;
    state surveying;
    state processing;
    state reporting;
    state fault;

    transition first idle;
    transition idle_to_calibrating
      first idle then calibrating
      accept CalibrateCommand;

    transition calibrating_to_surveying
      first calibrating then surveying
      accept CalibrationValid;

    transition surveying_to_processing
      first surveying then processing
      accept EchoBatchComplete;

    transition processing_to_reporting
      first processing then reporting
      accept EstimateComplete;

    transition reporting_to_surveying
      first reporting then surveying
      accept ContinueSurvey;

    transition any_to_fault
      first idle then fault
      accept CriticalFault;

    transition surveying_to_fault
      first surveying then fault
      accept CriticalFault;

    transition fault_to_idle
      first fault then idle
      accept FaultCleared;
  }

  part def SplitBeamTransducer {
    attribute nominalFrequency : Frequency = 120.0;
    attribute beamWidthDeg : Real = 7.0;
    attribute maxDepth : Depth = 500.0;

    port tx : AcousticTransmitPort;
    port rx : AcousticReceivePort;
    port power : PowerPort;
  }

  part def EchoSounderElectronics {
    attribute pingRateHz : Real = 2.0;
    attribute transmitPowerW : Real = 1000.0;
    attribute receiverDynamicRangeDb : Real = 120.0;

    port acousticTx : AcousticTransmitPort;
    port acousticRx : AcousticReceivePort;
    port dataIn : DataInPort;
    port processedOut : DataOutPort;

    perform action emit : EmitPing;
    perform action receive : ReceiveEchoes;
    perform action correct : CorrectForEnvironment;
    perform action estimate : EstimateFishBiomass;
  }

  part def EnvironmentalSensorSuite {
    attribute profileUpdatePeriod : TimeDuration = 30.0;
    port dataOut : DataInPort;
  }

  part def NavigationSystem {
    attribute fixRateHz : Real = 1.0;
    port dataOut : DataInPort;
  }

  part def SurveyComputer {
    attribute storageCapacityGb : Real = 2048.0;
    attribute minimumConfidence : Real = 0.80;

    port dataIn : DataOutPort;
    perform action store : StoreSurveyRecord;
  }

  part def FisheriesAcousticSurveySystem {
    doc
    /* Primary high-level function:
       The system emits calibrated acoustic pulses into the water column,
       receives echoes scattered by fish and plankton, corrects measurements
       for environmental and navigation context, and estimates fish distribution
       and biomass for fisheries assessment and management. */

    attribute surveyDepthLimit : Depth = 500.0;
    attribute operatingFrequency : Frequency = 120.0;
    attribute minimumDetectableTargetStrength : TargetStrength = -70.0;

    part transducer : SplitBeamTransducer;
    part echoSounder : EchoSounderElectronics;
    part environment : EnvironmentalSensorSuite;
    part navigation : NavigationSystem;
    part computer : SurveyComputer;

    port biomassProduct : DataOutPort;

    connection txLink connect echoSounder.acousticTx to transducer.tx;
    connection rxLink connect transducer.rx to echoSounder.acousticRx;
    connection environmentLink connect environment.dataOut to echoSounder.dataIn;
    connection navigationLink connect navigation.dataOut to echoSounder.dataIn;
    connection estimateLink connect echoSounder.processedOut to computer.dataIn;
    connection externalProductLink connect echoSounder.processedOut to biomassProduct;

    exhibit state surveyState : SurveyOperatingState;

    perform action surveyCycle {
      action sendPing : EmitPing {
        in frequency = operatingFrequency;
        in pulseLength = 0.001;
      }

      action collectEcho : ReceiveEchoes {
        in pulse = sendPing.pulse;
      }

      action compensateEcho : CorrectForEnvironment {
        in rawEcho = collectEcho.echo;
      }

      action computeBiomass : EstimateFishBiomass {
        in correctedEcho = compensateEcho.correctedEcho;
      }

      action archiveResult : StoreSurveyRecord {
        in estimate = computeBiomass.estimate;
      }
    }
  }

  requirement def DetectFishSchools {
    subject system : FisheriesAcousticSurveySystem;
    require constraint {
      system.minimumDetectableTargetStrength <= -65.0
    }
  }

  requirement def SurveyDepthCoverage {
    subject system : FisheriesAcousticSurveySystem;
    require constraint {
      system.surveyDepthLimit >= 300.0
    }
  }

  requirement def BiomassOutputRequirement {
    subject estimate : BiomassEstimate;
    require constraint {
      estimate.confidence >= 0.80
    }
  }

  requirement def AcousticFrequencyRequirement {
    subject system : FisheriesAcousticSurveySystem;
    require constraint {
      system.operatingFrequency >= 38.0 and system.operatingFrequency <= 200.0
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /* The fisheries acoustics system shall provide high-level assessment of
       fish presence, vertical distribution, and biomass by active acoustic
       sensing of the water column. */

    subject system : FisheriesAcousticSurveySystem;
    require constraint {
      system.surveyDepthLimit > 0.0
    }
  }

  part fisheriesSurveySystem : FisheriesAcousticSurveySystem;

  satisfy DetectFishSchools by fisheriesSurveySystem;
  satisfy SurveyDepthCoverage by fisheriesSurveySystem;
  satisfy AcousticFrequencyRequirement by fisheriesSurveySystem;
  satisfy PrimaryFunctionRequirement by fisheriesSurveySystem;
}