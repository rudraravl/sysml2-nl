package AcidEggSystemModel {

  value def Mass_g {
    unit = "g";
  }

  value def Volume_mL {
    unit = "mL";
  }

  value def Length_mm {
    unit = "mm";
  }

  value def Pressure_kPa {
    unit = "kPa";
  }

  value def Temperature_C {
    unit = "degC";
  }

  value def Time_s {
    unit = "s";
  }

  value def PH {
    unit = "pH";
  }

  value def Force_N {
    unit = "N";
  }

  item def AcidFluid {
    attribute volume : Volume_mL;
    attribute acidity : PH;
    attribute temperature : Temperature_C;
    attribute corrosivePotential : Real;
  }

  item def ShellFragment {
    attribute fragmentMass : Mass_g;
    attribute edgeSharpness : Real;
  }

  item def TargetSurface {
    attribute materialResistance : Real;
    attribute surfaceTemperature : Temperature_C;
  }

  item def NeutralizedResidue {
    attribute remainingAcidity : PH;
    attribute residueVolume : Volume_mL;
  }

  item def TriggerForce {
    attribute appliedForce : Force_N;
    attribute contactDuration : Time_s;
  }

  port def MechanicalContactPort {
    in item trigger : TriggerForce;
  }

  port def FluidReleasePort {
    out item releasedAcid : AcidFluid;
  }

  port def FragmentDispersalPort {
    out item fragments : ShellFragment;
  }

  port def TargetInterfacePort {
    out item acidToTarget : AcidFluid;
    out item shellDebris : ShellFragment;
    in item target : TargetSurface;
  }

  port def ResiduePort {
    out item residue : NeutralizedResidue;
  }

  interface def AcidDeliveryInterface {
    end source : FluidReleasePort;
    end target : TargetInterfacePort;
  }

  interface def FragmentDeliveryInterface {
    end source : FragmentDispersalPort;
    end target : TargetInterfacePort;
  }

  part def AcidCore {
    attribute containedVolume : Volume_mL = 48;
    attribute nominalAcidity : PH = 1.4;
    attribute storageTemperature : Temperature_C = 22;

    port releasePort : FluidReleasePort;

    action releaseAcid {
      out item acid : AcidFluid;
    }
  }

  part def ReactiveMembrane {
    attribute thickness : Length_mm = 1.2;
    attribute rupturePressure : Pressure_kPa = 85;
    attribute degradationLimitPH : PH = 2.0;

    port contactPort : MechanicalContactPort;

    state membraneState {
      state Intact;
      state Stressed;
      state Ruptured;

      transition first Intact;
      transition Intact to Stressed
        accept TriggerForce
        if trigger.appliedForce >= 8;

      transition Stressed to Ruptured
        accept TriggerForce
        if trigger.appliedForce >= 18;
    }
  }

  part def OuterShell {
    attribute shellMass : Mass_g = 16;
    attribute wallThickness : Length_mm = 2.5;
    attribute fractureForce : Force_N = 18;

    port fragmentPort : FragmentDispersalPort;

    action fractureShell {
      out item fragments : ShellFragment;
    }
  }

  part def StabilizingGel {
    attribute gelVolume : Volume_mL = 8;
    attribute dampingFactor : Real = 0.72;
    attribute neutralizationCapacity : Volume_mL = 4;
  }

  part def SafetyCoating {
    attribute coatingThickness : Length_mm = 0.4;
    attribute handlingPHIsolation : Real = 0.95;
    attribute maximumSafeStorageTemperature : Temperature_C = 35;
  }

  part def ImpactSensor {
    attribute activationForce : Force_N = 18;
    attribute minimumContactDuration : Time_s = 0.02;

    port impactInput : MechanicalContactPort;

    action detectImpact {
      in item force : TriggerForce;
      out attribute activated : Boolean;
    }
  }

  part def AcidEgg {
    attribute totalMass : Mass_g = 78;
    attribute length : Length_mm = 82;
    attribute diameter : Length_mm = 48;
    attribute safeStorageTemperature : Temperature_C = 5;
    attribute maximumStorageTemperature : Temperature_C = 35;

    part shell : OuterShell;
    part core : AcidCore;
    part membrane : ReactiveMembrane;
    part gel : StabilizingGel;
    part coating : SafetyCoating;
    part sensor : ImpactSensor;

    port impactPort : MechanicalContactPort;
    port effectPort : TargetInterfacePort;
    port residuePort : ResiduePort;

    bind impactPort = sensor.impactInput;
    bind impactPort = membrane.contactPort;

    connect core.releasePort to effectPort;
    connect shell.fragmentPort to effectPort;

    action deployAcid {
      in item target : TargetSurface;
      in item force : TriggerForce;
      out item deliveredAcid : AcidFluid;
      out item debris : ShellFragment;
      out item residue : NeutralizedResidue;

      first start;
      then senseImpact;
      then ruptureContainment;
      then releasePayload;
      then disperseShell;
      then formResidue;
      then done;

      action senseImpact {
        in item force : TriggerForce;
      }

      action ruptureContainment {
        in item force : TriggerForce;
      }

      action releasePayload {
        out item deliveredAcid : AcidFluid;
      }

      action disperseShell {
        out item debris : ShellFragment;
      }

      action formResidue {
        out item residue : NeutralizedResidue;
      }
    }

    state operationalState {
      state Stored;
      state Armed;
      state Impacted;
      state Releasing;
      state Spent;
      state UnsafeStorage;

      transition first Stored;

      transition Stored to Armed
        if safeStorageTemperature <= maximumStorageTemperature;

      transition Stored to UnsafeStorage
        if safeStorageTemperature > maximumStorageTemperature;

      transition Armed to Impacted
        accept TriggerForce
        if trigger.appliedForce >= sensor.activationForce;

      transition Impacted to Releasing
        if trigger.contactDuration >= sensor.minimumContactDuration;

      transition Releasing to Spent
        after 3 [Time_s];
    }
  }

  part def TargetZone {
    attribute exposedAreaDiameter : Length_mm = 120;
    attribute minimumMaterialResistance : Real = 0.25;

    port targetPort : TargetInterfacePort;
  }

  part def AcidEggEffectSystem {
    part acidEgg : AcidEgg;
    part targetZone : TargetZone;

    connect acidEgg.effectPort to targetZone.targetPort;

    action primaryFunction {
      in item target : TargetSurface;
      in item impact : TriggerForce;
      out item acidExposure : AcidFluid;
      out item shellDebris : ShellFragment;

      objective "Contain a reactive acidic payload during storage and handling, then rupture on sufficient impact to release acid and shell fragments onto a target surface.";
    }
  }

  requirement def ContainmentRequirement {
    subject egg : AcidEgg;
    require constraint {
      egg.core.containedVolume >= 45 and
      egg.coating.handlingPHIsolation >= 0.90 and
      egg.membrane.thickness >= 1.0
    }
  }

  requirement def ImpactActivationRequirement {
    subject egg : AcidEgg;
    require constraint {
      egg.sensor.activationForce >= 15 and
      egg.shell.fractureForce <= 25
    }
  }

  requirement def AcidPayloadRequirement {
    subject egg : AcidEgg;
    require constraint {
      egg.core.nominalAcidity <= 2.0 and
      egg.core.containedVolume >= 40
    }
  }

  requirement def SafeStorageRequirement {
    subject egg : AcidEgg;
    require constraint {
      egg.maximumStorageTemperature <= 35 and
      egg.coating.coatingThickness >= 0.3
    }
  }

  requirement def ResidueRequirement {
    subject egg : AcidEgg;
    require constraint {
      egg.gel.neutralizationCapacity >= 4
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : AcidEggEffectSystem;
    require constraint {
      system.acidEgg.core.containedVolume > 0 and
      system.acidEgg.shell.shellMass > 0
    }
  }

}