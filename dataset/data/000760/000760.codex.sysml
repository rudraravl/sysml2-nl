package SensitiveSkinSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value def CelsiusTemperature : Real;
  value def MicrometerLength : Real;
  value def MilligramPerCm2 : Real;
  value def PHValue : Real;
  value def RelativeHumidityPercent : Real;
  value def IrritantConcentration : Real;
  value def CytokineLevel : Real;
  value def NerveSignalRate : Real;
  value def BarrierIntegrityIndex : Real;
  value def SensitivityIndex : Real;

  item def ThermalStimulus {
    attribute surfaceTemperature : CelsiusTemperature;
    attribute rateOfChange : Real;
  }

  item def ChemicalStimulus {
    attribute irritantConcentration : IrritantConcentration;
    attribute pH : PHValue;
  }

  item def MechanicalStimulus {
    attribute pressure : Real;
    attribute shear : Real;
  }

  item def HydrationSignal {
    attribute stratumCorneumHydration : RelativeHumidityPercent;
    attribute transepidermalWaterLoss : MilligramPerCm2;
  }

  item def ImmuneMediatorSignal {
    attribute histamineLevel : CytokineLevel;
    attribute interleukinLevel : CytokineLevel;
    attribute prostaglandinLevel : CytokineLevel;
  }

  item def NeuralSignal {
    attribute firingRate : NerveSignalRate;
    attribute itchIntensity : SensitivityIndex;
    attribute painIntensity : SensitivityIndex;
  }

  item def ProtectiveResponse {
    attribute vasodilationLevel : SensitivityIndex;
    attribute inflammationLevel : SensitivityIndex;
    attribute avoidanceReflexLevel : SensitivityIndex;
    attribute repairActivationLevel : SensitivityIndex;
  }

  port def StimulusInputPort {
    in item thermalStimulus : ThermalStimulus;
    in item chemicalStimulus : ChemicalStimulus;
    in item mechanicalStimulus : MechanicalStimulus;
  }

  port def HydrationExchangePort {
    out item hydrationSignal : HydrationSignal;
  }

  port def ImmuneMediatorPort {
    out item mediatorSignal : ImmuneMediatorSignal;
  }

  port def NeuralAfferentPort {
    out item neuralSignal : NeuralSignal;
  }

  port def ProtectiveOutputPort {
    out item protectiveResponse : ProtectiveResponse;
  }

  part def EpidermalBarrier {
    attribute thickness : MicrometerLength = 70.0;
    attribute lipidLayerContinuity : BarrierIntegrityIndex = 0.72;
    attribute barrierIntegrity : BarrierIntegrityIndex = 0.68;
    attribute surfacePH : PHValue = 5.4;
    attribute hydration : RelativeHumidityPercent = 38.0;

    port stimulusIn : StimulusInputPort;
    port hydrationOut : HydrationExchangePort;

    action computeBarrierStatus {
      in item thermal : ThermalStimulus;
      in item chemical : ChemicalStimulus;
      in item mechanical : MechanicalStimulus;
      out item hydrationStatus : HydrationSignal;

      first start;
      then assessChemicalLoad;
      then assessMechanicalDisruption;
      then assessThermalStress;
      then updateWaterLoss;
      then done;

      action assessChemicalLoad;
      action assessMechanicalDisruption;
      action assessThermalStress;
      action updateWaterLoss;
    }
  }

  part def KeratinocyteLayer {
    attribute cytokineReleaseThreshold : SensitivityIndex = 0.42;
    attribute currentStressIndex : SensitivityIndex = 0.0;

    port stimulusIn : StimulusInputPort;
    port mediatorOut : ImmuneMediatorPort;

    action releaseMediators {
      in item barrierHydration : HydrationSignal;
      in item chemical : ChemicalStimulus;
      out item mediatorSignal : ImmuneMediatorSignal;

      first start;
      then evaluateBarrierDamage;
      then produceAlarmCytokines;
      then amplifyLocalInflammation;
      then done;

      action evaluateBarrierDamage;
      action produceAlarmCytokines;
      action amplifyLocalInflammation;
    }
  }

  part def CutaneousNerveEnding {
    attribute activationThreshold : SensitivityIndex = 0.35;
    attribute sensitizationLevel : SensitivityIndex = 0.64;
    attribute baselineFiringRate : NerveSignalRate = 2.0;

    port stimulusIn : StimulusInputPort;
    port mediatorIn : ImmuneMediatorPort;
    port neuralOut : NeuralAfferentPort;

    state def NerveEndingStateMachine {
      state resting;
      state sensitized;
      state firing;
      state desensitizing;

      transition resting_to_sensitized
        first resting
        accept ImmuneMediatorSignal
        if interleukinLevel > 0.40
        then sensitized;

      transition sensitized_to_firing
        first sensitized
        accept ThermalStimulus
        if surfaceTemperature > 32.0
        then firing;

      transition firing_to_desensitizing
        first firing
        accept ProtectiveResponse
        if avoidanceReflexLevel > 0.50
        then desensitizing;

      transition desensitizing_to_resting
        first desensitizing
        if sensitizationLevel < 0.30
        then resting;
    }

    action transduceStimulus {
      in item thermal : ThermalStimulus;
      in item chemical : ChemicalStimulus;
      in item mechanical : MechanicalStimulus;
      in item mediator : ImmuneMediatorSignal;
      out item neuralSignal : NeuralSignal;

      first start;
      then sumReceptorInputs;
      then applySensitizationGain;
      then encodeItchAndPain;
      then done;

      action sumReceptorInputs;
      action applySensitizationGain;
      action encodeItchAndPain;
    }
  }

  part def DermalMicrovasculature {
    attribute baselinePerfusion : Real = 1.0;
    attribute vasodilationThreshold : SensitivityIndex = 0.45;

    port mediatorIn : ImmuneMediatorPort;
    port protectiveOut : ProtectiveOutputPort;

    action regulatePerfusion {
      in item mediatorSignal : ImmuneMediatorSignal;
      out item vascularResponse : ProtectiveResponse;

      first start;
      then detectInflammatoryLoad;
      then increasePerfusion;
      then recruitRepairSupport;
      then done;

      action detectInflammatoryLoad;
      action increasePerfusion;
      action recruitRepairSupport;
    }
  }

  part def CentralPerceptionInterface {
    attribute perceivedSensitivity : SensitivityIndex = 0.0;
    attribute discomfortThreshold : SensitivityIndex = 0.30;

    port neuralIn : NeuralAfferentPort;
    port protectiveOut : ProtectiveOutputPort;

    action interpretCutaneousSignals {
      in item neuralSignal : NeuralSignal;
      out item response : ProtectiveResponse;

      first start;
      then classifySignalAsItchPainOrHeat;
      then estimateThreatLevel;
      then initiateAvoidanceAndCareBehavior;
      then done;

      action classifySignalAsItchPainOrHeat;
      action estimateThreatLevel;
      action initiateAvoidanceAndCareBehavior;
    }
  }

  part def SensitiveSkin {
    doc /* Primary high-level function: detect low-intensity environmental, chemical, thermal, and mechanical stimuli at the body surface, amplify protective warning signals when the barrier is vulnerable, and coordinate local repair, inflammation, and avoidance responses to preserve tissue integrity. */

    attribute overallSensitivity : SensitivityIndex = 0.70;
    attribute barrierReserve : BarrierIntegrityIndex = 0.62;
    attribute restingSurfaceTemperature : CelsiusTemperature = 33.0;
    attribute normalSurfacePH : PHValue = 5.5;

    port externalStimulus : StimulusInputPort;
    port neuralOutput : NeuralAfferentPort;
    port protectiveOutput : ProtectiveOutputPort;

    part barrier : EpidermalBarrier;
    part keratinocytes : KeratinocyteLayer;
    part nerveEndings : CutaneousNerveEnding;
    part microvasculature : DermalMicrovasculature;
    part perceptionInterface : CentralPerceptionInterface;

    connect externalStimulus to barrier.stimulusIn;
    connect externalStimulus to keratinocytes.stimulusIn;
    connect externalStimulus to nerveEndings.stimulusIn;

    connect barrier.hydrationOut to keratinocytes.mediatorOut;
    connect keratinocytes.mediatorOut to nerveEndings.mediatorIn;
    connect keratinocytes.mediatorOut to microvasculature.mediatorIn;

    connect nerveEndings.neuralOut to perceptionInterface.neuralIn;
    connect nerveEndings.neuralOut to neuralOutput;

    connect microvasculature.protectiveOut to protectiveOutput;
    connect perceptionInterface.protectiveOut to protectiveOutput;

    state def SensitiveSkinResponseStateMachine {
      state balanced {
        entry action maintainBarrierHomeostasis;
      }

      state vulnerable {
        entry action reduceIrritantTolerance;
      }

      state reactive {
        entry action amplifyNeuralWarning;
      }

      state inflamed {
        entry action recruitRepairAndImmuneSupport;
      }

      state recovering {
        entry action restoreBarrierLipidsAndHydration;
      }

      transition balanced_to_vulnerable
        first balanced
        accept HydrationSignal
        if stratumCorneumHydration < 30.0
        then vulnerable;

      transition vulnerable_to_reactive
        first vulnerable
        accept ChemicalStimulus
        if irritantConcentration > 0.25 or pH < 4.8 or pH > 6.4
        then reactive;

      transition reactive_to_inflamed
        first reactive
        accept ImmuneMediatorSignal
        if histamineLevel > 0.50 or interleukinLevel > 0.50
        then inflamed;

      transition inflamed_to_recovering
        first inflamed
        accept ProtectiveResponse
        if repairActivationLevel > 0.60
        then recovering;

      transition recovering_to_balanced
        first recovering
        accept HydrationSignal
        if stratumCorneumHydration >= 38.0 and transepidermalWaterLoss < 8.0
        then balanced;
    }

    action performPrimaryFunction {
      in item thermal : ThermalStimulus;
      in item chemical : ChemicalStimulus;
      in item mechanical : MechanicalStimulus;
      out item neuralSignal : NeuralSignal;
      out item protectiveResponse : ProtectiveResponse;

      first receiveStimulus;
      then evaluateBarrierCondition;
      then generateMediatorSignal;
      then transduceNeuralWarning;
      then coordinateProtectiveResponse;
      then updateRecoveryState;
      then done;

      action receiveStimulus;
      action evaluateBarrierCondition;
      action generateMediatorSignal;
      action transduceNeuralWarning;
      action coordinateProtectiveResponse;
      action updateRecoveryState;
    }
  }

  requirement def DetectLowIntensityStimuli {
    subject skin : SensitiveSkin;
    require constraint {
      skin.overallSensitivity >= 0.60
    }
    doc /* The sensitive skin system shall detect thermal, chemical, and mechanical inputs that may be tolerated by non-sensitive skin but represent potential irritation under reduced barrier reserve. */
  }

  requirement def PreserveBarrierIntegrity {
    subject skin : SensitiveSkin;
    require constraint {
      skin.barrierReserve >= 0.50
    }
    doc /* The sensitive skin system shall maintain sufficient epidermal barrier integrity to reduce water loss and limit irritant penetration during normal conditions. */
  }

  requirement def AmplifyProtectiveWarning {
    subject nerve : CutaneousNerveEnding;
    require constraint {
      nerve.sensitizationLevel >= nerve.activationThreshold
    }
    doc /* Cutaneous nerve endings shall amplify warning signals when immune mediators or barrier disruption indicate elevated tissue vulnerability. */
  }

  requirement def CoordinateRepairResponse {
    subject response : ProtectiveResponse;
    require constraint {
      response.repairActivationLevel >= 0.50 implies response.inflammationLevel >= 0.30
    }
    doc /* The system shall coordinate repair activation with controlled inflammatory support when sensitive skin enters a reactive or inflamed state. */
  }

  requirement def LimitExcessiveInflammation {
    subject response : ProtectiveResponse;
    require constraint {
      response.inflammationLevel <= 0.85
    }
    doc /* Protective inflammation shall remain bounded to avoid excessive discomfort and secondary barrier damage. */
  }

  satisfy DetectLowIntensityStimuli by SensitiveSkin::performPrimaryFunction;
  satisfy PreserveBarrierIntegrity by SensitiveSkin::barrier;
  satisfy AmplifyProtectiveWarning by SensitiveSkin::nerveEndings;
  satisfy CoordinateRepairResponse by SensitiveSkin::performPrimaryFunction;
  satisfy LimitExcessiveInflammation by SensitiveSkin::microvasculature;
}