package MetalFoamEnergyAbsorberSystem {

  attribute def Mass :> ISQ::mass {
    unit = SI::kg;
  }

  attribute def Length :> ISQ::length {
    unit = SI::m;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = SI::K;
  }

  attribute def HeatFlowRate :> ISQ::power {
    unit = SI::W;
  }

  attribute def Force :> ISQ::force {
    unit = SI::N;
  }

  attribute def Energy :> ISQ::energy {
    unit = SI::J;
  }

  attribute def Porosity {
    attribute value : Real;
  }

  attribute def Density :> ISQ::density {
    unit = SI::kg / SI::m^3;
  }

  attribute def ThermalConductivity {
    attribute value : Real;
    unit = SI::W / (SI::m * SI::K);
  }

  attribute def CrushStrength {
    attribute value : Real;
    unit = SI::Pa;
  }

  attribute def ImpactVelocity {
    attribute value : Real;
    unit = SI::m / SI::s;
  }

  item def ImpactLoad {
    attribute peakForce : Force;
    attribute velocity : ImpactVelocity;
    attribute kineticEnergy : Energy;
  }

  item def Heat {
    attribute rate : HeatFlowRate;
    attribute sourceTemperature : Temperature;
  }

  item def AirFlow {
    attribute massFlowRate : Real;
    attribute inletTemperature : Temperature;
  }

  item def MountingLoad {
    attribute staticForce : Force;
  }

  port def MechanicalPort {
    in item impact : ImpactLoad;
    out item reactedLoad : MountingLoad;
  }

  port def ThermalPort {
    in item heatIn : Heat;
    out item heatOut : Heat;
  }

  port def CoolingPort {
    in item airIn : AirFlow;
    out item airOut : AirFlow;
  }

  part def MetalFoamCore {
    attribute materialName : String = "open-cell aluminum metal foam";
    attribute porosity : Porosity = 0.89;
    attribute relativeDensity : Real = 0.11;
    attribute bulkDensity : Density = 297 [SI::kg / SI::m^3];
    attribute thermalConductivity : ThermalConductivity = 38 [SI::W / (SI::m * SI::K)];
    attribute plateauCrushStrength : CrushStrength = 4.5e6 [SI::Pa];
    attribute absorbedEnergyCapacity : Energy = 7200 [SI::J];
    attribute nominalThickness : Length = 0.045 [SI::m];
    attribute nominalMass : Mass = 1.8 [SI::kg];

    port mechanicalFace : MechanicalPort;
    port heatSpreaderFace : ThermalPort;
    port coolingFace : CoolingPort;

    action absorbImpact {
      in item impact : ImpactLoad;
      out item reacted : MountingLoad;
      attribute absorbedEnergy : Energy;
      attribute densificationReached : Boolean;

      first start;
      then calculateCrushWork;
      then limitPeakForce;
      then reportReaction;

      action calculateCrushWork {
        in item impact : ImpactLoad;
        out attribute absorbedEnergy : Energy;
        out attribute densificationReached : Boolean;
      }

      action limitPeakForce {
        in item impact : ImpactLoad;
        out item reacted : MountingLoad;
      }

      action reportReaction;
    }

    action conductAndSpreadHeat {
      in item heatIn : Heat;
      in item airIn : AirFlow;
      out item heatOut : Heat;
      out item airOut : AirFlow;

      first acceptHeat;
      then distributeThroughCellLigaments;
      then transferToAir;
      then rejectHeat;

      action acceptHeat;
      action distributeThroughCellLigaments;
      action transferToAir;
      action rejectHeat;
    }
  }

  part def FaceSheet {
    attribute materialName : String = "6061-T6 aluminum";
    attribute thickness : Length = 0.002 [SI::m];
    attribute mass : Mass = 0.42 [SI::kg];

    port outerMechanical : MechanicalPort;
    port innerMechanical : MechanicalPort;
    port thermalInterface : ThermalPort;
  }

  part def CoolingDuct {
    attribute ductLength : Length = 0.36 [SI::m];
    attribute hydraulicDiameter : Length = 0.018 [SI::m];
    attribute designAirMassFlowRate : Real = 0.035;

    port inlet : CoolingPort;
    port outlet : CoolingPort;
    port foamInterface : CoolingPort;

    action regulateAirflow {
      in item airIn : AirFlow;
      out item airOut : AirFlow;
    }
  }

  part def ProtectedPayload {
    attribute payloadName : String = "temperature-sensitive equipment module";
    attribute allowablePeakForce : Force = 8500 [SI::N];
    attribute maximumOperatingTemperature : Temperature = 333 [SI::K];

    port mountingInterface : MechanicalPort;
    port heatInterface : ThermalPort;
  }

  part def StructuralFrame {
    attribute frameMaterial : String = "carbon steel";
    attribute frameMass : Mass = 3.2 [SI::kg];

    port externalMount : MechanicalPort;
    port foamMount : MechanicalPort;
  }

  part def MetalFoamProtectionSystem {
    attribute systemMass : Mass;
    attribute primaryFunction : String =
      "Provide lightweight multifunctional protection by absorbing mechanical impact energy and spreading heat through an open-cell metal foam core.";

    part frontSheet : FaceSheet;
    part rearSheet : FaceSheet;
    part foamCore : MetalFoamCore;
    part coolingDuct : CoolingDuct;
    part payload : ProtectedPayload;
    part frame : StructuralFrame;

    port externalImpactPort : MechanicalPort;
    port heatSourcePort : ThermalPort;
    port coolingAirInlet : CoolingPort;
    port coolingAirOutlet : CoolingPort;
    port payloadInterface : MechanicalPort;

    connect externalImpactPort to frontSheet.outerMechanical;
    connect frontSheet.innerMechanical to foamCore.mechanicalFace;
    connect foamCore.mechanicalFace to rearSheet.innerMechanical;
    connect rearSheet.outerMechanical to payload.mountingInterface;
    connect payload.mountingInterface to payloadInterface;
    connect frame.foamMount to rearSheet.outerMechanical;

    connect heatSourcePort to payload.heatInterface;
    connect payload.heatInterface to rearSheet.thermalInterface;
    connect rearSheet.thermalInterface to foamCore.heatSpreaderFace;
    connect foamCore.heatSpreaderFace to frontSheet.thermalInterface;

    connect coolingAirInlet to coolingDuct.inlet;
    connect coolingDuct.foamInterface to foamCore.coolingFace;
    connect coolingDuct.outlet to coolingAirOutlet;

    state machine operationalBehavior {
      state Off;
      state Standby;
      state Protecting;
      state Cooling;
      state Saturated;
      state Fault;

      initial then Off;

      transition Off_to_Standby
        first Off
        accept PowerEnabled
        then Standby;

      transition Standby_to_Protecting
        first Standby
        accept ImpactDetected
        do foamCore.absorbImpact
        then Protecting;

      transition Protecting_to_Standby
        first Protecting
        accept ImpactEnergyBelowCapacity
        then Standby;

      transition Protecting_to_Saturated
        first Protecting
        accept FoamDensificationDetected
        then Saturated;

      transition Standby_to_Cooling
        first Standby
        accept HeatLoadDetected
        do foamCore.conductAndSpreadHeat
        then Cooling;

      transition Cooling_to_Standby
        first Cooling
        accept PayloadTemperatureNormal
        then Standby;

      transition Cooling_to_Fault
        first Cooling
        accept PayloadOverTemperature
        then Fault;

      transition Saturated_to_Fault
        first Saturated
        accept ContinuedImpactLoad
        then Fault;
    }

    action performPrimaryFunction {
      in item impact : ImpactLoad;
      in item heat : Heat;
      in item airIn : AirFlow;
      out item reactedLoad : MountingLoad;
      out item rejectedHeat : Heat;
      out item airOut : AirFlow;

      first receiveExternalLoads;
      then absorbMechanicalEnergy;
      then spreadThermalEnergy;
      then rejectHeatToCoolingAir;
      then protectPayload;

      action receiveExternalLoads;
      action absorbMechanicalEnergy {
        do foamCore.absorbImpact;
      }
      action spreadThermalEnergy {
        do foamCore.conductAndSpreadHeat;
      }
      action rejectHeatToCoolingAir {
        do coolingDuct.regulateAirflow;
      }
      action protectPayload;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : MetalFoamProtectionSystem;
    require constraint {
      system.primaryFunction ==
      "Provide lightweight multifunctional protection by absorbing mechanical impact energy and spreading heat through an open-cell metal foam core."
    }
  }

  requirement def ImpactEnergyAbsorptionRequirement {
    subject core : MetalFoamCore;
    require constraint {
      core.absorbedEnergyCapacity >= 6000 [SI::J]
    }
  }

  requirement def PeakForceLimitRequirement {
    subject payload : ProtectedPayload;
    require constraint {
      payload.allowablePeakForce <= 8500 [SI::N]
    }
  }

  requirement def ThermalProtectionRequirement {
    subject payload : ProtectedPayload;
    require constraint {
      payload.maximumOperatingTemperature <= 333 [SI::K]
    }
  }

  requirement def LightweightRequirement {
    subject system : MetalFoamProtectionSystem;
    require constraint {
      system.systemMass <= 7.5 [SI::kg]
    }
  }

  requirement def FoamPorosityRequirement {
    subject core : MetalFoamCore;
    require constraint {
      core.porosity.value >= 0.80 and core.porosity.value <= 0.95
    }
  }

  satisfy PrimaryFunctionRequirement by MetalFoamProtectionSystem;
  satisfy ImpactEnergyAbsorptionRequirement by MetalFoamCore;
  satisfy PeakForceLimitRequirement by ProtectedPayload;
  satisfy ThermalProtectionRequirement by ProtectedPayload;
  satisfy LightweightRequirement by MetalFoamProtectionSystem;
  satisfy FoamPorosityRequirement by MetalFoamCore;
}