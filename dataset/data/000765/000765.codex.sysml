package SkinElectrodeGelSystem {

  private import ScalarValues::*;
  private import ISQ::*;
  private import SI::*;

  attribute def Conductivity :> ISQ::electricalConductivity;
  attribute def Impedance :> ISQ::impedance;
  attribute def Temperature :> ISQ::thermodynamicTemperature;
  attribute def TimeDuration :> ISQ::duration;
  attribute def Area :> ISQ::area;
  attribute def Pressure :> ISQ::pressure;
  attribute def pHValue :> ScalarValues::Real;
  attribute def HydrationFraction :> ScalarValues::Real;

  item def IonicGel {
    attribute conductivity : Conductivity;
    attribute pH : pHValue;
    attribute waterContent : HydrationFraction;
    attribute chlorideIonConcentration : ScalarValues::Real;
    attribute viscosity : ScalarValues::Real;
  }

  item def BiopotentialSignal {
    attribute amplitude : ISQ::electricPotential;
    attribute frequency : ISQ::frequency;
    attribute sourceImpedance : Impedance;
  }

  item def SkinMoisture {
    attribute hydrationLevel : HydrationFraction;
  }

  item def ThermalEnergy {
    attribute temperature : Temperature;
  }

  port def SkinInterfacePort {
    in item skinSignal : BiopotentialSignal;
    inout item moisture : SkinMoisture;
    out item conditionedSignal : BiopotentialSignal;
  }

  port def ElectrodeInterfacePort {
    out item conditionedSignal : BiopotentialSignal;
    in item contactPressure : Pressure;
  }

  port def GelExposurePort {
    in item ambientThermalEnergy : ThermalEnergy;
    out item evaporatedWater : SkinMoisture;
  }

  part def SkinElectrodeGel {
    attribute contactArea : Area = 4.0 [SI::squareCentimetre];
    attribute nominalThickness : ISQ::length = 0.8 [SI::millimetre];
    attribute operatingTemperatureMin : Temperature = 283.15 [SI::kelvin];
    attribute operatingTemperatureMax : Temperature = 313.15 [SI::kelvin];
    attribute targetConductivity : Conductivity = 1.2 [SI::siemensPerMetre];
    attribute maximumInterfaceImpedance : Impedance = 5000 [SI::ohm];
    attribute nominalPH : pHValue = 6.8;
    attribute minimumWaterContent : HydrationFraction = 0.62;
    attribute usableLifeAfterOpening : TimeDuration = 24 [SI::hour];

    port skinPort : SkinInterfacePort;
    port electrodePort : ElectrodeInterfacePort;
    port exposurePort : GelExposurePort;

    item gelMedium : IonicGel {
      attribute conductivity = targetConductivity;
      attribute pH = nominalPH;
      attribute waterContent = 0.78;
      attribute chlorideIonConcentration = 0.9;
      attribute viscosity = 42.0;
    }

    part hydratedPolymerMatrix {
      attribute retainedWater : HydrationFraction = 0.78;
      attribute adhesionStrength : Pressure = 1800 [SI::pascal];
      attribute conformability : ScalarValues::Real = 0.92;
    }

    part ionicElectrolytePhase {
      attribute sodiumChlorideMassFraction : ScalarValues::Real = 0.015;
      attribute ionicMobilityFactor : ScalarValues::Real = 0.88;
      attribute conductivityContribution : Conductivity = 1.0 [SI::siemensPerMetre];
    }

    part skinContactLayer {
      attribute wettingCoverage : ScalarValues::Real = 0.97;
      attribute microgapFraction : ScalarValues::Real = 0.03;
      attribute localInterfaceImpedance : Impedance = 3200 [SI::ohm];
    }

    part electrodeContactLayer {
      attribute electrodeWettingCoverage : ScalarValues::Real = 0.98;
      attribute polarizationImpedance : Impedance = 850 [SI::ohm];
    }

    connection skinSignalPath connect skinPort.conditionedSignal to electrodePort.conditionedSignal;
    connection hydrationExchange connect skinPort.moisture to exposurePort.evaporatedWater;

    action conditionBiopotentialSignal {
      in item rawSignal : BiopotentialSignal;
      in item gel : IonicGel;
      out item lowImpedanceSignal : BiopotentialSignal;

      first start;
      then wetSkinSurface;
      then establishIonicBridge;
      then reduceMotionInducedNoise;
      then deliverConditionedSignal;
      then done;

      action wetSkinSurface {
        inout item gelAtSkin : IonicGel;
        out item moistureFilm : SkinMoisture;
      }

      action establishIonicBridge {
        in item moistureFilm : SkinMoisture;
        in item electrolyte : IonicGel;
        out item conductivePath : BiopotentialSignal;
      }

      action reduceMotionInducedNoise {
        in item conductivePath : BiopotentialSignal;
        out item stabilizedSignal : BiopotentialSignal;
      }

      action deliverConditionedSignal {
        in item stabilizedSignal : BiopotentialSignal;
        out item lowImpedanceSignal : BiopotentialSignal;
      }
    }

    state gelOperationalState {
      entry action initializeHydratedContact;

      state Sealed;
      state AppliedToSkin;
      state ConductiveBridgeEstablished;
      state Drying;
      state EndOfUse;

      transition first Sealed;
      transition applyGel
        first Sealed
        then AppliedToSkin;

      transition wettingComplete
        first AppliedToSkin
        then ConductiveBridgeEstablished
        if skinContactLayer.wettingCoverage >= 0.95;

      transition moistureLoss
        first ConductiveBridgeEstablished
        then Drying
        if hydratedPolymerMatrix.retainedWater < 0.68;

      transition impedanceTooHigh
        first Drying
        then EndOfUse
        if skinContactLayer.localInterfaceImpedance > maximumInterfaceImpedance;

      transition removeGel
        first ConductiveBridgeEstablished
        then EndOfUse;
    }
  }

  part def SkinElectrodeAssembly {
    part patientSkin {
      port bioSurface : SkinInterfacePort;
      attribute surfaceHydration : HydrationFraction = 0.55;
      attribute stratumCorneumImpedance : Impedance = 12000 [SI::ohm];
    }

    part conductiveGel : SkinElectrodeGel;

    part metalElectrode {
      port gelContact : ElectrodeInterfacePort;
      attribute electrodeMaterialWorkFunction : ISQ::electricPotential = 0.21 [SI::volt];
      attribute electrodeArea : Area = 4.0 [SI::squareCentimetre];
    }

    part biopotentialAcquisitionCircuit {
      port electrodeInput : ElectrodeInterfacePort;
      attribute inputImpedance : Impedance = 10000000 [SI::ohm];
      attribute noiseFloor : ISQ::electricPotential = 2.0 [SI::microvolt];
    }

    connection skinToGel connect patientSkin.bioSurface to conductiveGel.skinPort;
    connection gelToElectrode connect conductiveGel.electrodePort to metalElectrode.gelContact;
    connection electrodeToCircuit connect metalElectrode.gelContact to biopotentialAcquisitionCircuit.electrodeInput;
  }

  requirement def PrimaryFunctionRequirement {
    subject gel : SkinElectrodeGel;

    doc
    /* The skin electrode gel shall provide a hydrated ionic bridge between skin and electrode so that physiological electrical potentials are transferred with low interface impedance and reduced motion-related signal artifact. */

    require constraint {
      gel.skinContactLayer.localInterfaceImpedance <= gel.maximumInterfaceImpedance
    }

    require constraint {
      gel.gelMedium.waterContent >= gel.minimumWaterContent
    }

    require constraint {
      gel.gelMedium.pH >= 5.5 and gel.gelMedium.pH <= 7.5
    }
  }

  requirement def BiocompatibleContactRequirement {
    subject gel : SkinElectrodeGel;

    doc
    /* The gel shall remain mildly skin-compatible during intended use by maintaining near-neutral pH and a hydrated contact layer. */

    require constraint {
      gel.gelMedium.pH >= 5.5 and gel.gelMedium.pH <= 7.5
    }

    require constraint {
      gel.hydratedPolymerMatrix.retainedWater >= 0.62
    }
  }

  requirement def SignalCouplingRequirement {
    subject assembly : SkinElectrodeAssembly;

    doc
    /* The electrode assembly shall couple a biopotential signal from patient skin to the acquisition circuit through the conductive gel. */

    require constraint {
      assembly.conductiveGel.skinContactLayer.localInterfaceImpedance <= 5000 [SI::ohm]
    }

    require constraint {
      assembly.conductiveGel.ionicElectrolytePhase.conductivityContribution >= 0.8 [SI::siemensPerMetre]
    }
  }

  satisfy PrimaryFunctionRequirement by SkinElectrodeGel;
  satisfy BiocompatibleContactRequirement by SkinElectrodeGel;
  satisfy SignalCouplingRequirement by SkinElectrodeAssembly;
}