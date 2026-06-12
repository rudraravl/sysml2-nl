package BoseCorporationHighLevelModel {

  import ScalarValues::*;
  import SI::*;

  value def Decibel {
    unit = "dB";
    quantityKind = "sound pressure level";
  }

  value def Hertz {
    unit = "Hz";
    quantityKind = "frequency";
  }

  value def Watt {
    unit = "W";
    quantityKind = "power";
  }

  value def Volt {
    unit = "V";
    quantityKind = "electric potential";
  }

  value def Percent {
    unit = "%";
    quantityKind = "ratio";
  }

  value def US_Dollar {
    unit = "USD";
    quantityKind = "currency";
  }

  value def Hour {
    unit = "h";
    quantityKind = "time";
  }

  item def AudioSignal {
    attribute sampleRate : Hertz;
    attribute bitDepth : Integer;
    attribute channelCount : Integer;
    attribute averageLevel : Decibel;
  }

  item def AcousticOutput {
    attribute soundPressureLevel : Decibel;
    attribute lowFrequencyLimit : Hertz;
    attribute highFrequencyLimit : Hertz;
    attribute distortionPercent : Percent;
  }

  item def ProductDesign {
    attribute targetMarket : String;
    attribute acousticPerformanceGoal : Decibel;
    attribute batteryLifeGoal : Hour;
    attribute manufacturingCostTarget : US_Dollar;
  }

  item def FinishedAudioProduct {
    attribute modelName : String;
    attribute productCategory : String;
    attribute ratedPower : Watt;
    attribute retailPrice : US_Dollar;
    attribute warrantyPeriod : Hour;
  }

  item def CustomerFeedback {
    attribute satisfactionScore : Percent;
    attribute reportedIssue : String;
    attribute usageHours : Hour;
  }

  port def DigitalAudioPort {
    in item audioIn : AudioSignal;
    out item audioOut : AudioSignal;
  }

  port def AcousticPort {
    out item sound : AcousticOutput;
  }

  port def PowerPort {
    in attribute supplyVoltage : Volt;
    in attribute availablePower : Watt;
  }

  port def ProductFlowPort {
    out item product : FinishedAudioProduct;
  }

  port def FeedbackPort {
    in item feedback : CustomerFeedback;
  }

  port def DesignPort {
    in item designInput : ProductDesign;
    out item approvedDesign : ProductDesign;
  }

  part def ResearchAndDevelopment {
    port marketNeedPort : DesignPort;
    port feedbackPort : FeedbackPort;

    attribute annualResearchBudget : US_Dollar;
    attribute prototypeCount : Integer;
    attribute targetNoiseReduction : Decibel;

    action developAudioProduct {
      in item need : ProductDesign;
      in item feedback : CustomerFeedback;
      out item approvedDesign : ProductDesign;

      first start;
      then analyzeMarketNeed;
      then defineAcousticArchitecture;
      then buildPrototype;
      then validatePrototype;
      then approveDesign;
      then done;

      action analyzeMarketNeed;
      action defineAcousticArchitecture;
      action buildPrototype;
      action validatePrototype;
      action approveDesign;
    }
  }

  part def ManufacturingSystem {
    port designPort : DesignPort;
    port productPort : ProductFlowPort;

    attribute dailyCapacity : Integer;
    attribute yieldRate : Percent;
    attribute averageAssemblyPower : Watt;

    action manufactureAudioProduct {
      in item approvedDesign : ProductDesign;
      out item product : FinishedAudioProduct;

      first receiveDesign;
      then sourceComponents;
      then assembleElectronics;
      then tuneAcoustics;
      then performQualityTest;
      then packageProduct;
      then releaseProduct;

      action receiveDesign;
      action sourceComponents;
      action assembleElectronics;
      action tuneAcoustics;
      action performQualityTest;
      action packageProduct;
      action releaseProduct;
    }
  }

  part def DistributionAndSales {
    port productIn : ProductFlowPort;
    port customerFeedback : FeedbackPort;

    attribute activeRetailPartners : Integer;
    attribute directOnlineRevenue : US_Dollar;
    attribute averageDeliveryTime : Hour;

    action deliverCustomerValue {
      in item product : FinishedAudioProduct;
      out item feedback : CustomerFeedback;

      first listProduct;
      then sellProduct;
      then deliverProduct;
      then supportCustomer;
      then collectFeedback;

      action listProduct;
      action sellProduct;
      action deliverProduct;
      action supportCustomer;
      action collectFeedback;
    }
  }

  part def SmartAudioDevice {
    port power : PowerPort;
    port wirelessAudio : DigitalAudioPort;
    port acousticOutput : AcousticPort;

    attribute batteryStateOfCharge : Percent;
    attribute amplifierPower : Watt;
    attribute maximumOutputLevel : Decibel;
    attribute activeNoiseReduction : Decibel;
    attribute operatingFrequencyLow : Hertz;
    attribute operatingFrequencyHigh : Hertz;

    part signalProcessor {
      port digitalAudio : DigitalAudioPort;
      attribute processingLatencyMs : Real;
      attribute noiseCancellationDepth : Decibel;
    }

    part amplifier {
      port powerInput : PowerPort;
      attribute outputPower : Watt;
      attribute efficiency : Percent;
    }

    part transducerArray {
      port acousticPort : AcousticPort;
      attribute driverCount : Integer;
      attribute sensitivity : Decibel;
      attribute frequencyLow : Hertz;
      attribute frequencyHigh : Hertz;
    }

    connection signalToAmplifier
      connect signalProcessor.digitalAudio.audioOut to wirelessAudio.audioOut;

    connection amplifierPowerConnection
      connect power to amplifier.powerInput;

    connection acousticEmission
      connect transducerArray.acousticPort to acousticOutput;

    state def OperatingStates {
      state Off;
      state Standby;
      state Pairing;
      state PlayingAudio;
      state NoiseCancelling;
      state Fault;

      transition Off_to_Standby
        first Off
        accept powerButtonPressed
        then Standby;

      transition Standby_to_Pairing
        first Standby
        accept pairingRequested
        then Pairing;

      transition Pairing_to_PlayingAudio
        first Pairing
        accept audioSourceConnected
        then PlayingAudio;

      transition PlayingAudio_to_NoiseCancelling
        first PlayingAudio
        accept noiseCancellationEnabled
        then NoiseCancelling;

      transition Any_to_Fault
        first PlayingAudio
        accept overTemperatureDetected
        then Fault;

      transition Fault_to_Standby
        first Fault
        accept faultCleared
        then Standby;
    }

    action reproduceAudio {
      in item sourceSignal : AudioSignal;
      out item sound : AcousticOutput;

      first receiveDigitalAudio;
      then processSignal;
      then amplifySignal;
      then convertToAcousticEnergy;
      then emitSound;

      action receiveDigitalAudio;
      action processSignal;
      action amplifySignal;
      action convertToAcousticEnergy;
      action emitSound;
    }
  }

  part def BoseCorporationEnterprise {
    attribute enterpriseName : String = "Bose Corporation";
    attribute primaryFunction : String =
      "Design, engineer, manufacture, distribute, and support premium audio and noise-control products that transform electrical and digital audio signals into high-quality acoustic experiences for customers.";

    part researchAndDevelopment : ResearchAndDevelopment {
      attribute annualResearchBudget = 450000000 [US_Dollar];
      attribute prototypeCount = 320;
      attribute targetNoiseReduction = 30 [Decibel];
    }

    part manufacturing : ManufacturingSystem {
      attribute dailyCapacity = 85000;
      attribute yieldRate = 98.5 [Percent];
      attribute averageAssemblyPower = 250000 [Watt];
    }

    part distributionAndSales : DistributionAndSales {
      attribute activeRetailPartners = 1200;
      attribute directOnlineRevenue = 900000000 [US_Dollar];
      attribute averageDeliveryTime = 72 [Hour];
    }

    part representativeProduct : SmartAudioDevice {
      attribute batteryStateOfCharge = 100 [Percent];
      attribute amplifierPower = 20 [Watt];
      attribute maximumOutputLevel = 100 [Decibel];
      attribute activeNoiseReduction = 28 [Decibel];
      attribute operatingFrequencyLow = 20 [Hertz];
      attribute operatingFrequencyHigh = 20000 [Hertz];
    }

    connection feedbackToResearch
      connect distributionAndSales.customerFeedback to researchAndDevelopment.feedbackPort;

    connection designToManufacturing
      connect researchAndDevelopment.marketNeedPort to manufacturing.designPort;

    connection productToDistribution
      connect manufacturing.productPort to distributionAndSales.productIn;

    action performPrimaryEnterpriseFunction {
      in item customerNeed : ProductDesign;
      out item deliveredProduct : FinishedAudioProduct;
      out item customerResponse : CustomerFeedback;

      first identifyCustomerNeed;
      then createProductDesign;
      then manufactureProduct;
      then distributeProduct;
      then supportUse;
      then improveNextDesign;

      action identifyCustomerNeed;
      action createProductDesign;
      action manufactureProduct;
      action distributeProduct;
      action supportUse;
      action improveNextDesign;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject enterprise : BoseCorporationEnterprise;

    doc
      "The enterprise shall provide a complete capability for transforming customer audio needs into engineered audio products and services.";

    require constraint {
      enterprise.researchAndDevelopment.targetNoiseReduction >= 20 [Decibel]
    }

    require constraint {
      enterprise.manufacturing.yieldRate >= 95 [Percent]
    }
  }

  requirement def AudioPerformanceRequirement {
    subject product : SmartAudioDevice;

    doc
      "The representative Bose audio device shall reproduce consumer audio over the audible frequency range with controlled output level and active noise reduction.";

    require constraint {
      product.operatingFrequencyLow <= 20 [Hertz]
    }

    require constraint {
      product.operatingFrequencyHigh >= 20000 [Hertz]
    }

    require constraint {
      product.activeNoiseReduction >= 20 [Decibel]
    }

    require constraint {
      product.maximumOutputLevel >= 90 [Decibel]
    }
  }

  requirement def CustomerValueRequirement {
    subject enterprise : BoseCorporationEnterprise;

    doc
      "The enterprise shall close the loop from product delivery to customer feedback so that field experience informs future product design.";

    require constraint {
      enterprise.distributionAndSales.averageDeliveryTime <= 120 [Hour]
    }

    require constraint {
      enterprise.distributionAndSales.activeRetailPartners >= 500
    }
  }

  part boseSystem : BoseCorporationEnterprise;

  satisfy PrimaryFunctionRequirement by boseSystem;
  satisfy CustomerValueRequirement by boseSystem;
  satisfy AudioPerformanceRequirement by boseSystem.representativeProduct;
}