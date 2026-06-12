package PitometerLogModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Speed {
    :>> quantityKind = ISQ::speed;
    :>> unit = SI::metrePerSecond;
  }

  attribute def Distance {
    :>> quantityKind = ISQ::length;
    :>> unit = SI::metre;
  }

  attribute def Pressure {
    :>> quantityKind = ISQ::pressure;
    :>> unit = SI::pascal;
  }

  attribute def Density {
    :>> quantityKind = ISQ::massDensity;
    :>> unit = SI::kilogramPerCubicMetre;
  }

  attribute def Temperature {
    :>> quantityKind = ISQ::thermodynamicTemperature;
    :>> unit = SI::kelvin;
  }

  attribute def TimeInterval {
    :>> quantityKind = ISQ::time;
    :>> unit = SI::second;
  }

  item def StaticPressureSample {
    attribute pressure : Pressure;
    attribute sampleTime : TimeInterval;
  }

  item def DynamicPressureSample {
    attribute pressure : Pressure;
    attribute sampleTime : TimeInterval;
  }

  item def DifferentialPressureSample {
    attribute differentialPressure : Pressure;
    attribute sampleTime : TimeInterval;
  }

  item def SpeedIndication {
    attribute speedThroughWater : Speed;
    attribute confidence : Real;
    attribute sampleTime : TimeInterval;
  }

  item def DistanceIndication {
    attribute distanceThroughWater : Distance;
    attribute elapsedTime : TimeInterval;
  }

  item def CalibrationData {
    attribute zeroOffset : Pressure;
    attribute scaleFactor : Real;
    attribute waterDensityReference : Density;
  }

  port def PressureSensePort {
    out pressureSample : StaticPressureSample;
  }

  port def DynamicSensePort {
    out pressureSample : DynamicPressureSample;
  }

  port def DifferentialPressurePort {
    in staticPressure : StaticPressureSample;
    in dynamicPressure : DynamicPressureSample;
    out differentialPressure : DifferentialPressureSample;
  }

  port def SpeedOutputPort {
    out speed : SpeedIndication;
  }

  port def DistanceOutputPort {
    out distance : DistanceIndication;
  }

  port def PowerPort {
    in voltage : Real;
    in current : Real;
  }

  port def MaintenancePort {
    in calibrationCommand : CalibrationData;
    out healthStatus : String;
  }

  part def PitometerTube {
    port dynamicPort : DynamicSensePort;
    port staticPort : PressureSensePort;

    attribute immersionDepth : Distance;
    attribute tubeDiameter : Distance;
    attribute alignmentAngle : Real;
  }

  part def PressureManifold {
    port staticIn : PressureSensePort;
    port dynamicIn : DynamicSensePort;
    port differentialOut : DifferentialPressurePort;

    attribute trappedAirVolume : Real;
    attribute maximumWorkingPressure : Pressure;
  }

  part def DifferentialPressureTransducer {
    port pressureIn : DifferentialPressurePort;
    port electricalPower : PowerPort;

    attribute measuredDifferentialPressure : Pressure;
    attribute sensorRange : Pressure;
    attribute sensorAccuracy : Pressure;
    attribute sensorTemperature : Temperature;
  }

  part def SignalConditioner {
    port sensorInput : DifferentialPressurePort;
    port power : PowerPort;

    attribute filteredDifferentialPressure : Pressure;
    attribute filterTimeConstant : TimeInterval;
    attribute zeroOffset : Pressure;
    attribute gain : Real;
  }

  part def SpeedComputer {
    port conditionedInput : DifferentialPressurePort;
    port speedOutput : SpeedOutputPort;
    port distanceOutput : DistanceOutputPort;
    port maintenance : MaintenancePort;

    attribute waterDensity : Density = 1025 [SI::kilogramPerCubicMetre];
    attribute currentSpeed : Speed;
    attribute accumulatedDistance : Distance;
    attribute integrationPeriod : TimeInterval = 1 [SI::second];
    attribute validSignal : Boolean;

    action computeSpeed {
      in dp : Pressure;
      in density : Density;
      out speed : Speed;

      assert density > 0 [SI::kilogramPerCubicMetre];
      assert dp >= 0 [SI::pascal];

      speed = sqrt(2 * dp / density);
    }

    action integrateDistance {
      in speed : Speed;
      in period : TimeInterval;
      in previousDistance : Distance;
      out newDistance : Distance;

      newDistance = previousDistance + speed * period;
    }

    action applyCalibration {
      in rawDifferentialPressure : Pressure;
      in calibration : CalibrationData;
      out correctedDifferentialPressure : Pressure;

      correctedDifferentialPressure =
        (rawDifferentialPressure - calibration.zeroOffset) * calibration.scaleFactor;
    }
  }

  part def BridgeRepeaterDisplay {
    port speedInput : SpeedOutputPort;
    port distanceInput : DistanceOutputPort;
    port power : PowerPort;

    attribute displayedSpeed : Speed;
    attribute displayedDistance : Distance;
    attribute displayRefreshPeriod : TimeInterval = 1 [SI::second];
  }

  part def AlarmUnit {
    port speedInput : SpeedOutputPort;
    port power : PowerPort;

    attribute maximumValidSpeed : Speed = 40 [SI::metrePerSecond];
    attribute minimumValidSpeed : Speed = 0 [SI::metrePerSecond];
    attribute faultDetected : Boolean;
  }

  connection def PressureTubeConnection {
    end source : PressureSensePort;
    end target : PressureSensePort;
  }

  connection def DynamicTubeConnection {
    end source : DynamicSensePort;
    end target : DynamicSensePort;
  }

  connection def DifferentialSignalConnection {
    end source : DifferentialPressurePort;
    end target : DifferentialPressurePort;
  }

  connection def SpeedSignalConnection {
    end source : SpeedOutputPort;
    end target : SpeedOutputPort;
  }

  connection def DistanceSignalConnection {
    end source : DistanceOutputPort;
    end target : DistanceOutputPort;
  }

  part def PitometerLogSystem {
    port shipPower : PowerPort;
    port maintenanceAccess : MaintenancePort;
    port indicatedSpeed : SpeedOutputPort;
    port indicatedDistance : DistanceOutputPort;

    part tube : PitometerTube;
    part manifold : PressureManifold;
    part transducer : DifferentialPressureTransducer;
    part conditioner : SignalConditioner;
    part computer : SpeedComputer;
    part display : BridgeRepeaterDisplay;
    part alarm : AlarmUnit;

    connect tube.staticPort to manifold.staticIn;
    connect tube.dynamicPort to manifold.dynamicIn;
    connect manifold.differentialOut to transducer.pressureIn;
    connect transducer.pressureIn to conditioner.sensorInput;
    connect conditioner.sensorInput to computer.conditionedInput;
    connect computer.speedOutput to display.speedInput;
    connect computer.distanceOutput to display.distanceInput;
    connect computer.speedOutput to alarm.speedInput;
    connect computer.speedOutput to indicatedSpeed;
    connect computer.distanceOutput to indicatedDistance;
    connect shipPower to transducer.electricalPower;
    connect shipPower to conditioner.power;
    connect shipPower to display.power;
    connect shipPower to alarm.power;
    connect maintenanceAccess to computer.maintenance;

    action performPrimaryFunction {
      in staticPressure : StaticPressureSample;
      in dynamicPressure : DynamicPressureSample;
      out speedThroughWater : SpeedIndication;
      out distanceThroughWater : DistanceIndication;

      objective {
        "Sense static and dynamic water pressure at the hull, compute vessel speed through water from differential pressure, integrate speed over time, and present speed and distance indications to the bridge."
      }
    }

    state def OperatingStateMachine {
      state off;
      state standby;
      state zeroing;
      state logging;
      state degraded;
      state fault;

      transition initial then off;

      transition powerApplied
        first off
        then standby;

      transition startZeroing
        first standby
        then zeroing;

      transition zeroComplete
        first zeroing
        then logging;

      transition signalInvalid
        first logging
        then degraded;

      transition signalRecovered
        first degraded
        then logging;

      transition unrecoverableFault
        first standby
        then fault;

      transition unrecoverableFaultWhileLogging
        first logging
        then fault;

      transition reset
        first fault
        then standby;

      transition powerRemovedFromStandby
        first standby
        then off;

      transition powerRemovedFromLogging
        first logging
        then off;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject pitometerLog : PitometerLogSystem;

    doc "The Pitometer log system shall determine vessel speed through water by measuring the pressure difference between dynamic and static water pressure at the hull, computing speed from that differential pressure, integrating speed to obtain distance through water, and displaying both values to ship operators."

    require constraint {
      pitometerLog.computer.currentSpeed >= 0 [SI::metrePerSecond]
    }
  }

  requirement def DifferentialPressureMeasurementRequirement {
    subject transducer : DifferentialPressureTransducer;

    doc "The differential pressure transducer shall measure the pressure difference supplied by the Pitometer tube and manifold over the expected vessel operating envelope."

    require constraint {
      transducer.sensorRange >= 100000 [SI::pascal]
    }
  }

  requirement def SpeedComputationRequirement {
    subject computer : SpeedComputer;

    doc "The speed computer shall compute speed through water from corrected differential pressure using the Pitot relation for incompressible seawater."

    require constraint {
      computer.waterDensity > 1000 [SI::kilogramPerCubicMetre] and
      computer.waterDensity < 1035 [SI::kilogramPerCubicMetre]
    }
  }

  requirement def DistanceIntegrationRequirement {
    subject computer : SpeedComputer;

    doc "The speed computer shall integrate computed speed through water over elapsed time to produce accumulated distance through water."

    require constraint {
      computer.integrationPeriod <= 1 [SI::second]
    }
  }

  requirement def BridgeIndicationRequirement {
    subject display : BridgeRepeaterDisplay;

    doc "The bridge repeater display shall continuously present current speed through water and accumulated distance through water during logging operation."

    require constraint {
      display.displayRefreshPeriod <= 1 [SI::second]
    }
  }

  requirement def FaultDetectionRequirement {
    subject alarm : AlarmUnit;

    doc "The alarm unit shall detect invalid or out-of-range speed indications and raise a fault condition."

    require constraint {
      alarm.maximumValidSpeed > alarm.minimumValidSpeed
    }
  }

  satisfy PrimaryFunctionRequirement by PitometerLogSystem;
  satisfy DifferentialPressureMeasurementRequirement by DifferentialPressureTransducer;
  satisfy SpeedComputationRequirement by SpeedComputer;
  satisfy DistanceIntegrationRequirement by SpeedComputer;
  satisfy BridgeIndicationRequirement by BridgeRepeaterDisplay;
  satisfy FaultDetectionRequirement by AlarmUnit;
}