package BrineSystemModel {

  value type Mass [kg];
  value type Volume [L];
  value type Time [s];
  value type Temperature [degC];
  value type Pressure [kPa];
  value type FlowRate [L/min];
  value type MassFraction [percent];
  value type Density [kg/m^3];
  value type ElectricalConductivity [mS/cm];
  value type Power [W];

  item def Water {
    attribute volume: Volume;
    attribute temperature: Temperature;
  }

  item def SodiumChloride {
    attribute mass: Mass;
    attribute purity: MassFraction;
  }

  item def Brine {
    attribute volume: Volume;
    attribute salinity: MassFraction;
    attribute temperature: Temperature;
    attribute density: Density;
    attribute conductivity: ElectricalConductivity;
  }

  item def WasteBrine :> Brine {
    attribute contaminantFraction: MassFraction;
  }

  port def WaterPort {
    in item water: Water;
  }

  port def SaltPort {
    in item salt: SodiumChloride;
  }

  port def BrinePort {
    inout item brine: Brine;
  }

  port def WastePort {
    out item waste: WasteBrine;
  }

  port def PowerPort {
    in attribute suppliedPower: Power;
  }

  port def ControlPort {
    in attribute targetSalinity: MassFraction;
    in attribute targetFlowRate: FlowRate;
    out attribute measuredSalinity: MassFraction;
    out attribute systemReady: Boolean;
  }

  part def SaltStorage {
    attribute capacity: Mass = 500 [kg];
    attribute storedSalt: Mass;
    port saltOut: SaltPort;
  }

  part def WaterSupply {
    attribute availableVolume: Volume;
    attribute supplyPressure: Pressure;
    port waterOut: WaterPort;
  }

  part def MixingTank {
    attribute workingVolume: Volume = 1000 [L];
    attribute currentVolume: Volume;
    attribute agitatorPower: Power = 750 [W];

    port waterIn: WaterPort;
    port saltIn: SaltPort;
    port brineOut: BrinePort;
    port powerIn: PowerPort;

    perform action mixBrine: PrepareBrine;
  }

  part def SalinitySensor {
    attribute measurementRangeMin: MassFraction = 0 [percent];
    attribute measurementRangeMax: MassFraction = 26 [percent];
    attribute accuracy: MassFraction = 0.2 [percent];

    port sampleIn: BrinePort;
    port controlOut: ControlPort;
  }

  part def TemperatureSensor {
    attribute accuracy: Temperature = 0.5 [degC];
    port sampleIn: BrinePort;
  }

  part def TransferPump {
    attribute ratedFlowRate: FlowRate = 80 [L/min];
    attribute ratedPressure: Pressure = 300 [kPa];
    attribute motorPower: Power = 1500 [W];

    port brineIn: BrinePort;
    port brineOut: BrinePort;
    port powerIn: PowerPort;
    port commandIn: ControlPort;
  }

  part def BrineReservoir {
    attribute storageVolume: Volume = 5000 [L];
    attribute minimumUsableVolume: Volume = 250 [L];

    port brineIn: BrinePort;
    port brineOut: BrinePort;
  }

  part def PurgeValve {
    attribute purgeFlowRate: FlowRate = 30 [L/min];

    port brineIn: BrinePort;
    port wasteOut: WastePort;
    port commandIn: ControlPort;
  }

  part def BrineControlUnit {
    attribute targetSalinity: MassFraction = 23 [percent];
    attribute salinityTolerance: MassFraction = 0.5 [percent];
    attribute targetDeliveryFlowRate: FlowRate = 60 [L/min];

    port powerIn: PowerPort;
    port operatorCommand: ControlPort;
    port sensorFeedback: ControlPort;
    port pumpCommand: ControlPort;
    port purgeCommand: ControlPort;

    perform action regulateBrine: RegulateBrineQuality;
    exhibit state brineOperatingState: BrineSystemState;
  }

  part def BrineSystem {
    doc /* Primary function: prepare, store, monitor, and deliver brine at controlled salinity, temperature, and flow rate for downstream use. */

    attribute nominalSalinity: MassFraction = 23 [percent];
    attribute nominalTemperature: Temperature = 20 [degC];
    attribute nominalDeliveryFlowRate: FlowRate = 60 [L/min];

    part waterSupply: WaterSupply;
    part saltStorage: SaltStorage;
    part mixingTank: MixingTank;
    part reservoir: BrineReservoir;
    part salinitySensor: SalinitySensor;
    part temperatureSensor: TemperatureSensor;
    part transferPump: TransferPump;
    part purgeValve: PurgeValve;
    part controller: BrineControlUnit;

    port powerInput: PowerPort;
    port controlInterface: ControlPort;
    port brineDelivery: BrinePort;
    port wasteDischarge: WastePort;

    connect waterSupply.waterOut to mixingTank.waterIn;
    connect saltStorage.saltOut to mixingTank.saltIn;
    connect mixingTank.brineOut to reservoir.brineIn;
    connect reservoir.brineOut to transferPump.brineIn;
    connect transferPump.brineOut to brineDelivery;
    connect reservoir.brineOut to salinitySensor.sampleIn;
    connect reservoir.brineOut to temperatureSensor.sampleIn;
    connect reservoir.brineOut to purgeValve.brineIn;
    connect purgeValve.wasteOut to wasteDischarge;

    connect powerInput to mixingTank.powerIn;
    connect powerInput to transferPump.powerIn;
    connect powerInput to controller.powerIn;

    connect controlInterface to controller.operatorCommand;
    connect salinitySensor.controlOut to controller.sensorFeedback;
    connect controller.pumpCommand to transferPump.commandIn;
    connect controller.purgeCommand to purgeValve.commandIn;
  }

  action def PrepareBrine {
    in item feedWater: Water;
    in item saltFeed: SodiumChloride;
    in attribute targetSalinity: MassFraction;
    out item preparedBrine: Brine;

    action meterWater;
    action meterSalt;
    action dissolveSalt;
    action circulateMixture;
    action verifySalinity;
    action releaseToReservoir;

    first start;
    then meterWater;
    then meterSalt;
    then dissolveSalt;
    then circulateMixture;
    then verifySalinity;
    then releaseToReservoir;
    then done;
  }

  action def RegulateBrineQuality {
    in item storedBrine: Brine;
    in attribute targetSalinity: MassFraction;
    in attribute targetFlowRate: FlowRate;
    out item deliveredBrine: Brine;
    out item purgedBrine: WasteBrine;

    action readSalinity;
    action compareToTarget;
    action commandMixingCorrection;
    action commandPumpFlow;
    action purgeOffSpecBrine;
    action confirmDelivery;

    first start;
    then readSalinity;
    then compareToTarget;

    if storedBrine.salinity >= targetSalinity - 0.5 [percent] and storedBrine.salinity <= targetSalinity + 0.5 [percent] then commandPumpFlow;
    if storedBrine.salinity < targetSalinity - 0.5 [percent] then commandMixingCorrection;
    if storedBrine.salinity > targetSalinity + 0.5 [percent] then purgeOffSpecBrine;

    then confirmDelivery;
    then done;
  }

  state def BrineSystemState {
    state Off;
    state Standby;
    state Filling;
    state Mixing;
    state QualityCheck;
    state Ready;
    state Delivering;
    state Purging;
    state Fault;

    transition initialToOff first Off;
    transition powerApplied from Off to Standby;
    transition startBatch from Standby to Filling;
    transition waterAndSaltLoaded from Filling to Mixing;
    transition mixingComplete from Mixing to QualityCheck;
    transition withinSpecification from QualityCheck to Ready;
    transition deliveryRequested from Ready to Delivering;
    transition deliveryComplete from Delivering to Ready;
    transition offSpecHighSalinity from QualityCheck to Purging;
    transition purgeComplete from Purging to Filling;
    transition sensorFailure from Standby to Fault;
    transition pumpFailure from Delivering to Fault;
    transition reset from Fault to Standby;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The brine system shall prepare, store, monitor, and deliver brine for downstream consumption. */
    subject brineSystem: BrineSystem;
    require constraint {
      brineSystem.nominalSalinity == 23 [percent]
    }
  }

  requirement def SalinityControlRequirement {
    doc /* Delivered brine salinity shall remain within plus or minus 0.5 percent of the commanded salinity during normal delivery. */
    subject delivered: Brine;
    attribute commandedSalinity: MassFraction = 23 [percent];

    require constraint {
      delivered.salinity >= commandedSalinity - 0.5 [percent] and
      delivered.salinity <= commandedSalinity + 0.5 [percent]
    }
  }

  requirement def DeliveryFlowRequirement {
    doc /* The transfer pump shall deliver brine at a controlled nominal flow rate for downstream use. */
    subject pump: TransferPump;

    require constraint {
      pump.ratedFlowRate >= 60 [L/min]
    }
  }

  requirement def StorageCapacityRequirement {
    doc /* The reservoir shall store enough brine to support sustained operation between preparation batches. */
    subject reservoir: BrineReservoir;

    require constraint {
      reservoir.storageVolume >= 5000 [L]
    }
  }

  requirement def OffSpecPurgeRequirement {
    doc /* Brine outside acceptable salinity limits shall be isolated from delivery and routed to waste discharge. */
    subject purgeValve: PurgeValve;
    subject brine: Brine;

    require constraint {
      brine.salinity < 22.5 [percent] or brine.salinity > 23.5 [percent]
    }
  }

  requirement def SensorAccuracyRequirement {
    doc /* The salinity sensor shall measure brine concentration accurately enough to support closed-loop salinity control. */
    subject sensor: SalinitySensor;

    require constraint {
      sensor.accuracy <= 0.2 [percent]
    }
  }

}