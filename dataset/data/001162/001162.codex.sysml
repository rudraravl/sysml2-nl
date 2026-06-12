package OlfactometerSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Concentration;
  attribute def FlowRate;
  attribute def Pressure;
  attribute def Temperature;
  attribute def Humidity;
  attribute def TimeDuration;
  attribute def Voltage;
  attribute def Percent;

  item def CleanAir {
    attribute temperature : Temperature;
    attribute humidity : Humidity;
    attribute pressure : Pressure;
    attribute flowRate : FlowRate;
  }

  item def OdorantVapor {
    attribute compoundName : String;
    attribute concentration : Concentration;
    attribute vaporPressure : Pressure;
    attribute carrierFlowRate : FlowRate;
  }

  item def StimulusMixture {
    attribute targetOdorant : String;
    attribute concentration : Concentration;
    attribute totalFlowRate : FlowRate;
    attribute dilutionRatio : Real;
    attribute pulseDuration : TimeDuration;
    attribute temperature : Temperature;
    attribute humidity : Humidity;
  }

  item def ExhaustGas {
    attribute residualConcentration : Concentration;
    attribute flowRate : FlowRate;
  }

  item def ControlCommand {
    attribute stimulusId : String;
    attribute targetConcentration : Concentration;
    attribute pulseDuration : TimeDuration;
    attribute interStimulusInterval : TimeDuration;
    attribute selectedOdorChannel : Integer;
  }

  item def SensorMeasurement {
    attribute measuredFlowRate : FlowRate;
    attribute measuredPressure : Pressure;
    attribute measuredTemperature : Temperature;
    attribute measuredHumidity : Humidity;
    attribute measuredConcentration : Concentration;
    attribute timestamp : TimeDuration;
  }

  item def SystemStatus {
    attribute ready : Boolean;
    attribute faultActive : Boolean;
    attribute activeOdorChannel : Integer;
    attribute remainingPulseTime : TimeDuration;
  }

  port def AirInletPort {
    in item airIn : CleanAir;
  }

  port def GasOutletPort {
    out item gasOut : ExhaustGas;
  }

  port def OdorantPort {
    out item vaporOut : OdorantVapor;
  }

  port def MixturePort {
    inout item mixture : StimulusMixture;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def StatusPort {
    out item status : SystemStatus;
  }

  port def MeasurementPort {
    out item measurement : SensorMeasurement;
  }

  part def AirSupply {
    attribute nominalPressure : Pressure = 200.0 [kPa];
    attribute maximumPressure : Pressure = 350.0 [kPa];
    attribute nominalTemperature : Temperature = 293.15 [K];

    port outlet : AirInletPort;
  }

  part def FilterAssembly {
    attribute particulateEfficiency : Percent = 99.9;
    attribute activatedCarbonMass : MassValue = 250.0 [g];
    attribute pressureDrop : Pressure = 5.0 [kPa];

    port inlet : AirInletPort;
    port outlet : AirInletPort;
  }

  part def Humidifier {
    attribute targetRelativeHumidity : Percent = 45.0;
    attribute humidityTolerance : Percent = 3.0;
    attribute reservoirVolume : VolumeValue = 0.5 [L];

    port inlet : AirInletPort;
    port outlet : AirInletPort;
  }

  part def OdorantReservoir {
    attribute channelId : Integer;
    attribute compoundName : String;
    attribute liquidVolume : VolumeValue;
    attribute maximumSafeConcentration : Concentration;
    attribute storageTemperature : Temperature = 293.15 [K];

    port vaporOutlet : OdorantPort;
  }

  part def MassFlowController {
    attribute controllerId : String;
    attribute minimumFlowRate : FlowRate = 0.0 [L/min];
    attribute maximumFlowRate : FlowRate = 10.0 [L/min];
    attribute setpointFlowRate : FlowRate;
    attribute accuracy : Percent = 1.0;

    port inlet : AirInletPort;
    port outlet : MixturePort;

    action setFlow {
      in requestedFlowRate : FlowRate;
      out accepted : Boolean;
    }

    action closeFlow {
      out closed : Boolean;
    }
  }

  part def SolenoidValve {
    attribute valveId : String;
    attribute responseTime : TimeDuration = 10.0 [ms];
    attribute energizedVoltage : Voltage = 24.0 [V];
    attribute isOpen : Boolean = false;

    port inlet : MixturePort;
    port outlet : MixturePort;

    action openValve {
      out opened : Boolean;
    }

    action closeValve {
      out closed : Boolean;
    }
  }

  part def MixingManifold {
    attribute internalVolume : VolumeValue = 25.0 [mL];
    attribute maximumChannels : Integer = 8;
    attribute mixingEfficiency : Percent = 98.0;

    port cleanAirIn : MixturePort;
    port odorantIn : MixturePort;
    port mixtureOut : MixturePort;
  }

  part def StimulusDeliveryNozzle {
    attribute nozzleDiameter : LengthValue = 4.0 [mm];
    attribute distanceToSubject : LengthValue = 20.0 [mm];
    attribute outletVelocity : Real;

    port mixtureIn : MixturePort;
    port subjectOutlet : MixturePort;
  }

  part def ExhaustCapture {
    attribute captureEfficiency : Percent = 95.0;
    attribute exhaustFlowRate : FlowRate = 12.0 [L/min];

    port intake : MixturePort;
    port exhaustOutlet : GasOutletPort;
  }

  part def FlowSensor {
    attribute samplePeriod : TimeDuration = 20.0 [ms];
    attribute measurementRange : FlowRate = 20.0 [L/min];

    port sensedLine : MixturePort;
    port measurementOut : MeasurementPort;
  }

  part def PressureSensor {
    attribute maximumPressure : Pressure = 500.0 [kPa];
    attribute samplePeriod : TimeDuration = 20.0 [ms];

    port sensedLine : MixturePort;
    port measurementOut : MeasurementPort;
  }

  part def ConcentrationSensor {
    attribute sensorType : String = "photoionization detector";
    attribute detectionLimit : Concentration = 1.0 [ppm];
    attribute samplePeriod : TimeDuration = 100.0 [ms];

    port sensedLine : MixturePort;
    port measurementOut : MeasurementPort;
  }

  part def ControlComputer {
    attribute controllerName : String = "Olfactometer Sequencer";
    attribute samplingPeriod : TimeDuration = 10.0 [ms];
    attribute maximumStimulusDuration : TimeDuration = 30.0 [s];
    attribute minimumInterStimulusInterval : TimeDuration = 5.0 [s];

    port commandIn : CommandPort;
    port statusOut : StatusPort;
    port measurementIn : MeasurementPort;

    action validateCommand {
      in command : ControlCommand;
      out valid : Boolean;
    }

    action computeDilution {
      in targetConcentration : Concentration;
      in sourceConcentration : Concentration;
      out cleanAirFlow : FlowRate;
      out odorantFlow : FlowRate;
    }

    action triggerStimulus {
      in selectedChannel : Integer;
      in pulseDuration : TimeDuration;
      out delivered : Boolean;
    }

    action stopStimulus {
      out stopped : Boolean;
    }

    state controlState {
      entry; then Standby;

      state Standby;
      state Priming;
      state Ready;
      state DeliveringStimulus;
      state Purging;
      state Fault;

      transition Standby_to_Priming
        first Standby
        accept ControlCommand
        then Priming;

      transition Priming_to_Ready
        first Priming
        if measurementIn::measurement.measuredPressure > 100.0 [kPa]
        then Ready;

      transition Ready_to_DeliveringStimulus
        first Ready
        accept ControlCommand
        then DeliveringStimulus;

      transition DeliveringStimulus_to_Purging
        first DeliveringStimulus
        if statusOut::status.remainingPulseTime <= 0.0 [s]
        then Purging;

      transition Purging_to_Ready
        first Purging
        if measurementIn::measurement.measuredConcentration <= 1.0 [ppm]
        then Ready;

      transition Any_to_Fault
        first Standby
        if measurementIn::measurement.measuredPressure > 350.0 [kPa]
        then Fault;

      transition Fault_to_Standby
        first Fault
        accept ControlCommand
        then Standby;
    }
  }

  part def HumanSubjectInterface {
    attribute subjectId : String;
    attribute nasalCannulaInstalled : Boolean;
    attribute exposureLimit : TimeDuration = 300.0 [s];

    port stimulusIn : MixturePort;
  }

  part def Olfactometer {
    attribute primaryFunction : String = "Generate and deliver controlled, repeatable odorant stimuli by mixing clean carrier air with selected odorant vapor at specified concentration, flow rate, and duration.";
    attribute supportedOdorChannels : Integer = 4;
    attribute totalStimulusFlowRate : FlowRate = 8.0 [L/min];
    attribute concentrationAccuracy : Percent = 5.0;
    attribute flowAccuracy : Percent = 1.0;
    attribute maximumOutletPressure : Pressure = 120.0 [kPa];

    port airInput : AirInletPort;
    port commandInput : CommandPort;
    port subjectOutput : MixturePort;
    port exhaustOutput : GasOutletPort;
    port statusOutput : StatusPort;

    part airSupply : AirSupply;
    part filter : FilterAssembly;
    part humidifier : Humidifier;

    part cleanAirController : MassFlowController {
      attribute controllerId = "MFC-CLEAN";
      attribute maximumFlowRate = 10.0 [L/min];
    }

    part odorantController : MassFlowController {
      attribute controllerId = "MFC-ODOR";
      attribute maximumFlowRate = 2.0 [L/min];
    }

    part odorantA : OdorantReservoir {
      attribute channelId = 1;
      attribute compoundName = "Isoamyl acetate";
      attribute liquidVolume = 20.0 [mL];
      attribute maximumSafeConcentration = 100.0 [ppm];
    }

    part odorantB : OdorantReservoir {
      attribute channelId = 2;
      attribute compoundName = "Linalool";
      attribute liquidVolume = 20.0 [mL];
      attribute maximumSafeConcentration = 80.0 [ppm];
    }

    part odorantC : OdorantReservoir {
      attribute channelId = 3;
      attribute compoundName = "Eucalyptol";
      attribute liquidVolume = 20.0 [mL];
      attribute maximumSafeConcentration = 60.0 [ppm];
    }

    part odorantD : OdorantReservoir {
      attribute channelId = 4;
      attribute compoundName = "Blank carrier air";
      attribute liquidVolume = 0.0 [mL];
      attribute maximumSafeConcentration = 0.0 [ppm];
    }

    part valveA : SolenoidValve {
      attribute valveId = "VALVE-A";
    }

    part valveB : SolenoidValve {
      attribute valveId = "VALVE-B";
    }

    part valveC : SolenoidValve {
      attribute valveId = "VALVE-C";
    }

    part valveD : SolenoidValve {
      attribute valveId = "VALVE-D";
    }

    part manifold : MixingManifold;
    part nozzle : StimulusDeliveryNozzle;
    part exhaust : ExhaustCapture;
    part flowSensor : FlowSensor;
    part pressureSensor : PressureSensor;
    part concentrationSensor : ConcentrationSensor;
    part controller : ControlComputer;

    connect airSupply.outlet to filter.inlet;
    connect filter.outlet to humidifier.inlet;
    connect humidifier.outlet to cleanAirController.inlet;
    connect cleanAirController.outlet to manifold.cleanAirIn;

    connect odorantA.vaporOutlet to valveA.inlet;
    connect odorantB.vaporOutlet to valveB.inlet;
    connect odorantC.vaporOutlet to valveC.inlet;
    connect odorantD.vaporOutlet to valveD.inlet;

    connect valveA.outlet to odorantController.inlet;
    connect valveB.outlet to odorantController.inlet;
    connect valveC.outlet to odorantController.inlet;
    connect valveD.outlet to odorantController.inlet;

    connect odorantController.outlet to manifold.odorantIn;
    connect manifold.mixtureOut to flowSensor.sensedLine;
    connect manifold.mixtureOut to pressureSensor.sensedLine;
    connect manifold.mixtureOut to concentrationSensor.sensedLine;
    connect manifold.mixtureOut to nozzle.mixtureIn;

    connect nozzle.subjectOutlet to subjectOutput;
    connect nozzle.subjectOutlet to exhaust.intake;
    connect exhaust.exhaustOutlet to exhaustOutput;

    connect commandInput to controller.commandIn;
    connect flowSensor.measurementOut to controller.measurementIn;
    connect pressureSensor.measurementOut to controller.measurementIn;
    connect concentrationSensor.measurementOut to controller.measurementIn;
    connect controller.statusOut to statusOutput;

    action deliverOdorStimulus {
      in command : ControlCommand;
      out mixture : StimulusMixture;
      out status : SystemStatus;

      first start;
      then validate : controller.validateCommand {
        in command = deliverOdorStimulus::command;
      }
      then compute : controller.computeDilution {
        in targetConcentration = deliverOdorStimulus::command.targetConcentration;
      }
      then setCleanAir : cleanAirController.setFlow {
        in requestedFlowRate = compute.cleanAirFlow;
      }
      then setOdorantFlow : odorantController.setFlow {
        in requestedFlowRate = compute.odorantFlow;
      }
      then trigger : controller.triggerStimulus {
        in selectedChannel = deliverOdorStimulus::command.selectedOdorChannel;
        in pulseDuration = deliverOdorStimulus::command.pulseDuration;
      }
      then stop : controller.stopStimulus;
      then done;
    }
  }

  part subjectInterface : HumanSubjectInterface {
    attribute subjectId = "Research participant";
    attribute nasalCannulaInstalled = true;
  }

  part system : Olfactometer;

  connect system.subjectOutput to subjectInterface.stimulusIn;

  requirement def PrimaryFunctionRequirement {
    doc /* The olfactometer shall generate a controlled odorant stimulus by selecting one odorant channel, mixing its vapor with conditioned clean carrier air, and delivering the resulting mixture to a subject interface at commanded concentration, flow rate, and duration. */
  }

  requirement def FlowControlRequirement {
    doc /* The olfactometer shall maintain total delivered stimulus flow within plus or minus one percent of the commanded total flow rate during the active stimulus pulse. */
    attribute requiredAccuracy : Percent = 1.0;
  }

  requirement def ConcentrationControlRequirement {
    doc /* The olfactometer shall maintain delivered odorant concentration within plus or minus five percent of the commanded concentration after the settling interval. */
    attribute requiredAccuracy : Percent = 5.0;
    attribute settlingTime : TimeDuration = 500.0 [ms];
  }

  requirement def PulseTimingRequirement {
    doc /* The olfactometer shall start and stop each odorant pulse within twenty milliseconds of the commanded pulse timing. */
    attribute timingTolerance : TimeDuration = 20.0 [ms];
  }

  requirement def PurgeRequirement {
    doc /* The olfactometer shall purge the delivery path after each stimulus until residual odorant concentration is less than or equal to one part per million before declaring the system ready for the next stimulus. */
    attribute maximumResidualConcentration : Concentration = 1.0 [ppm];
  }

  requirement def SafetyPressureRequirement {
    doc /* The olfactometer shall enter the fault state and close odorant valves if measured outlet pressure exceeds the maximum safe outlet pressure. */
    attribute maximumSafeOutletPressure : Pressure = 120.0 [kPa];
  }

  requirement primaryFunction : PrimaryFunctionRequirement;
  requirement flowControl : FlowControlRequirement;
  requirement concentrationControl : ConcentrationControlRequirement;
  requirement pulseTiming : PulseTimingRequirement;
  requirement purge : PurgeRequirement;
  requirement safetyPressure : SafetyPressureRequirement;

  satisfy primaryFunction by system;
  satisfy flowControl by system.cleanAirController;
  satisfy flowControl by system.odorantController;
  satisfy concentrationControl by system.manifold;
  satisfy concentrationControl by system.concentrationSensor;
  satisfy pulseTiming by system.controller;
  satisfy pulseTiming by system.valveA;
  satisfy pulseTiming by system.valveB;
  satisfy pulseTiming by system.valveC;
  satisfy pulseTiming by system.valveD;
  satisfy purge by system.exhaust;
  satisfy safetyPressure by system.pressureSensor;
  satisfy safetyPressure by system.controller;

}