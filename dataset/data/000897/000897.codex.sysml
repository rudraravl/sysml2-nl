package HydraulicRamModel {
  import ScalarValues::*;
  import SI::*;

  attribute def Pressure {
    attribute value : Real;
    attribute unit : String = "Pa";
  }

  attribute def FlowRate {
    attribute value : Real;
    attribute unit : String = "m^3/s";
  }

  attribute def Volume {
    attribute value : Real;
    attribute unit : String = "m^3";
  }

  attribute def Length {
    attribute value : Real;
    attribute unit : String = "m";
  }

  attribute def Mass {
    attribute value : Real;
    attribute unit : String = "kg";
  }

  attribute def Efficiency {
    attribute value : Real;
    attribute unit : String = "1";
  }

  attribute def TimeDuration {
    attribute value : Real;
    attribute unit : String = "s";
  }

  item def Water {
    attribute density : Mass;
    attribute temperature : Real;
  }

  item def HydraulicEnergy {
    attribute pressure : Pressure;
    attribute flowRate : FlowRate;
    attribute head : Length;
  }

  port def WaterPort {
    inout item water : Water;
    attribute pressure : Pressure;
    attribute flowRate : FlowRate;
    attribute elevationHead : Length;
  }

  port def VentPort {
    out item dischargedWater : Water;
    attribute dischargeFlowRate : FlowRate;
  }

  port def MechanicalValvePort {
    in item actuatingWater : Water;
    attribute forceEquivalentPressure : Pressure;
  }

  connection def HydraulicConnection {
    end a : WaterPort;
    end b : WaterPort;
  }

  part def WaterSource {
    attribute availableHead : Length = 2.5;
    attribute availableFlowRate : FlowRate = 0.003;
    port outlet : WaterPort;
  }

  part def DrivePipe {
    attribute length : Length = 12.0;
    attribute internalDiameter : Length = 0.05;
    attribute containedVolume : Volume = 0.0236;
    port inlet : WaterPort;
    port outlet : WaterPort;
  }

  part def WasteValve {
    attribute openPressureThreshold : Pressure = 15000.0;
    attribute closePressureThreshold : Pressure = 42000.0;
    attribute cycleOpenTime : TimeDuration = 0.45;
    port inlet : WaterPort;
    port discharge : VentPort;
  }

  part def DeliveryCheckValve {
    attribute crackingPressure : Pressure = 90000.0;
    attribute reverseLeakageFlowRate : FlowRate = 0.0;
    port inlet : WaterPort;
    port outlet : WaterPort;
  }

  part def PressureChamber {
    attribute airVolume : Volume = 0.004;
    attribute waterVolume : Volume = 0.002;
    attribute nominalPressure : Pressure = 180000.0;
    port inlet : WaterPort;
    port outlet : WaterPort;
  }

  part def DeliveryPipe {
    attribute length : Length = 35.0;
    attribute elevationLift : Length = 8.0;
    attribute internalDiameter : Length = 0.025;
    port inlet : WaterPort;
    port outlet : WaterPort;
  }

  part def StorageTank {
    attribute capacity : Volume = 0.5;
    attribute storedWater : Volume = 0.0;
    port inlet : WaterPort;
  }

  part def HydraulicRam {
    attribute driveHead : Length = 2.5;
    attribute deliveryHead : Length = 8.0;
    attribute targetDeliveryFlowRate : FlowRate = 0.00025;
    attribute volumetricEfficiency : Efficiency = 0.62;
    attribute cyclePeriod : TimeDuration = 1.2;

    port sourceInlet : WaterPort;
    port deliveredOutlet : WaterPort;
    port wasteOutlet : VentPort;

    part source : WaterSource;
    part drivePipe : DrivePipe;
    part wasteValve : WasteValve;
    part checkValve : DeliveryCheckValve;
    part pressureChamber : PressureChamber;
    part deliveryPipe : DeliveryPipe;
    part storageTank : StorageTank;

    connect source.outlet to drivePipe.inlet;
    connect drivePipe.outlet to wasteValve.inlet;
    connect drivePipe.outlet to checkValve.inlet;
    connect checkValve.outlet to pressureChamber.inlet;
    connect pressureChamber.outlet to deliveryPipe.inlet;
    connect deliveryPipe.outlet to storageTank.inlet;
    connect sourceInlet to source.outlet;
    connect deliveryPipe.outlet to deliveredOutlet;
    connect wasteValve.discharge to wasteOutlet;

    action operateRam {
      first startDriveFlow;
      then accelerateDriveWater;
      then closeWasteValveByWaterHammer;
      then openDeliveryCheckValve;
      then compressAirInPressureChamber;
      then dischargeWaterToDeliveryPipe;
      then closeDeliveryCheckValve;
      then reopenWasteValve;
    }

    action startDriveFlow {
      in item sourceWater : Water;
      out item movingDriveWater : Water;
    }

    action accelerateDriveWater {
      in item movingDriveWater : Water;
      out item highMomentumWater : Water;
    }

    action closeWasteValveByWaterHammer {
      in item highMomentumWater : Water;
      out item pressurePulse : HydraulicEnergy;
    }

    action openDeliveryCheckValve {
      in item pressurePulse : HydraulicEnergy;
      out item liftedWater : Water;
    }

    action compressAirInPressureChamber {
      in item liftedWater : Water;
      out item storedHydraulicEnergy : HydraulicEnergy;
    }

    action dischargeWaterToDeliveryPipe {
      in item storedHydraulicEnergy : HydraulicEnergy;
      out item deliveredWater : Water;
    }

    action closeDeliveryCheckValve {
      in item deliveredWater : Water;
      out item isolatedDeliveryColumn : Water;
    }

    action reopenWasteValve {
      out item resetDriveFlow : Water;
    }

    state ramCycle {
      state idle;
      state driveFlowing;
      state wasteValveClosing;
      state pressureSurge;
      state deliveryFlowing;
      state pressureRecovery;

      initial then idle;

      transition idle_to_driveFlowing
        first idle
        then driveFlowing;

      transition driveFlowing_to_wasteValveClosing
        first driveFlowing
        then wasteValveClosing
        if drivePipe.outlet.pressure.value >= wasteValve.closePressureThreshold.value;

      transition wasteValveClosing_to_pressureSurge
        first wasteValveClosing
        then pressureSurge;

      transition pressureSurge_to_deliveryFlowing
        first pressureSurge
        then deliveryFlowing
        if checkValve.inlet.pressure.value >= checkValve.crackingPressure.value;

      transition deliveryFlowing_to_pressureRecovery
        first deliveryFlowing
        then pressureRecovery
        if pressureChamber.nominalPressure.value > deliveryPipe.inlet.pressure.value;

      transition pressureRecovery_to_driveFlowing
        first pressureRecovery
        then driveFlowing;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject ram : HydraulicRam;

    doc
    /*
      The hydraulic ram shall use the kinetic energy of a falling drive-water flow
      to pump a smaller portion of that water to a storage point at a higher
      elevation without external electrical, thermal, or rotary mechanical power.
    */

    require constraint {
      ram.deliveryHead.value > ram.driveHead.value
    }

    require constraint {
      ram.targetDeliveryFlowRate.value > 0.0
    }
  }

  requirement def PassiveOperationRequirement {
    subject ram : HydraulicRam;

    require constraint {
      ram.volumetricEfficiency.value >= 0.4 and ram.volumetricEfficiency.value <= 0.8
    }
  }

  requirement def PressureChamberRequirement {
    subject ram : HydraulicRam;

    require constraint {
      ram.pressureChamber.airVolume.value > ram.pressureChamber.waterVolume.value
    }
  }

  requirement def DeliveryRequirement {
    subject ram : HydraulicRam;

    require constraint {
      ram.deliveryPipe.elevationLift.value == ram.deliveryHead.value
    }
  }

  part hydraulicRamSystem : HydraulicRam;

  satisfy PrimaryFunctionRequirement by hydraulicRamSystem;
  satisfy PassiveOperationRequirement by hydraulicRamSystem;
  satisfy PressureChamberRequirement by hydraulicRamSystem;
  satisfy DeliveryRequirement by hydraulicRamSystem;
}