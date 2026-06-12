package WheatstoneBridgeSystem {

  attribute def Voltage {
    unit = "V";
  }

  attribute def Current {
    unit = "A";
  }

  attribute def Resistance {
    unit = "Ohm";
  }

  attribute def Power {
    unit = "W";
  }

  attribute def Temperature {
    unit = "degC";
  }

  attribute def Ratio {
    unit = "1";
  }

  item def ElectricalPotential {
    attribute voltage : Voltage;
  }

  item def ElectricalCurrent {
    attribute current : Current;
  }

  item def BridgeMeasurement {
    attribute excitationVoltage : Voltage;
    attribute differentialOutputVoltage : Voltage;
    attribute inferredResistanceChange : Resistance;
    attribute normalizedImbalance : Ratio;
    attribute sensorTemperature : Temperature;
  }

  port def ElectricalPort {
    inout item potential : ElectricalPotential;
    inout item flow : ElectricalCurrent;
  }

  port def MeasurementPort {
    out item measurement : BridgeMeasurement;
  }

  port def ControlPort {
    in item enableCommand : Boolean;
    out item readyStatus : Boolean;
    out item faultStatus : Boolean;
  }

  part def PrecisionResistor {
    port terminalA : ElectricalPort;
    port terminalB : ElectricalPort;

    attribute nominalResistance : Resistance;
    attribute actualResistance : Resistance;
    attribute tolerance : Ratio;
    attribute powerDissipation : Power;
    attribute temperatureCoefficient : Ratio;

    constraint resistanceWithinTolerance {
      actualResistance >= nominalResistance * (1.0 - tolerance) and
      actualResistance <= nominalResistance * (1.0 + tolerance)
    }

    constraint dissipatedPowerLimit {
      powerDissipation <= 0.125 [W]
    }
  }

  part def SensingResistor :> PrecisionResistor {
    attribute sensedTemperature : Temperature;
    attribute resistanceAtReference : Resistance;
    attribute sensitivity : Resistance;

    constraint resistanceRespondsToTemperature {
      actualResistance == resistanceAtReference + sensitivity * sensedTemperature
    }
  }

  part def ExcitationSource {
    port positive : ElectricalPort;
    port negative : ElectricalPort;
    port control : ControlPort;

    attribute outputVoltage : Voltage = 5.0 [V];
    attribute maximumCurrent : Current = 0.020 [A];
    attribute enabled : Boolean;

    action provideExcitation {
      in enable : Boolean;
      out voltage : Voltage;

      first start;
      then decide;
      if enable then energized;
      else disabled;

      action energized {
        voltage = outputVoltage;
        enabled = true;
      }

      action disabled {
        voltage = 0.0 [V];
        enabled = false;
      }
    }
  }

  part def DifferentialAmplifier {
    port inputPositive : ElectricalPort;
    port inputNegative : ElectricalPort;
    port output : MeasurementPort;

    attribute gain : Ratio = 128.0;
    attribute inputOffsetVoltage : Voltage = 0.000010 [V];
    attribute amplifiedVoltage : Voltage;

    action amplifyBridgeSignal {
      in positiveNodeVoltage : Voltage;
      in negativeNodeVoltage : Voltage;
      out outputVoltage : Voltage;

      outputVoltage = gain * ((positiveNodeVoltage - negativeNodeVoltage) + inputOffsetVoltage);
    }
  }

  part def AnalogToDigitalConverter {
    port analogInput : MeasurementPort;
    port digitalOutput : MeasurementPort;

    attribute resolutionBits : Integer = 24;
    attribute referenceVoltage : Voltage = 2.5 [V];
    attribute sampleRate : Real = 1000.0;

    action sampleMeasurement {
      in analogMeasurement : BridgeMeasurement;
      out digitalMeasurement : BridgeMeasurement;

      digitalMeasurement = analogMeasurement;
    }
  }

  part def WheatstoneBridgeNetwork {
    port excitationPositive : ElectricalPort;
    port excitationNegative : ElectricalPort;
    port sensePositive : ElectricalPort;
    port senseNegative : ElectricalPort;

    part upperLeft : PrecisionResistor {
      nominalResistance = 350.0 [Ohm];
      tolerance = 0.001;
    }

    part lowerLeft : PrecisionResistor {
      nominalResistance = 350.0 [Ohm];
      tolerance = 0.001;
    }

    part upperRight : PrecisionResistor {
      nominalResistance = 350.0 [Ohm];
      tolerance = 0.001;
    }

    part sensorElement : SensingResistor {
      nominalResistance = 350.0 [Ohm];
      resistanceAtReference = 350.0 [Ohm];
      tolerance = 0.001;
      sensitivity = 0.02 [Ohm];
    }

    connection excitationPositiveToUpperLeft connect excitationPositive to upperLeft.terminalA;
    connection excitationPositiveToUpperRight connect excitationPositive to upperRight.terminalA;
    connection upperLeftToLowerLeftSenseNode connect upperLeft.terminalB to lowerLeft.terminalA;
    connection upperRightToSensorSenseNode connect upperRight.terminalB to sensorElement.terminalA;
    connection lowerLeftToExcitationNegative connect lowerLeft.terminalB to excitationNegative;
    connection sensorToExcitationNegative connect sensorElement.terminalB to excitationNegative;
    connection leftSenseNode connect upperLeft.terminalB to sensePositive;
    connection rightSenseNode connect upperRight.terminalB to senseNegative;

    attribute excitationVoltage : Voltage;
    attribute leftDividerVoltage : Voltage;
    attribute rightDividerVoltage : Voltage;
    attribute differentialOutputVoltage : Voltage;
    attribute nominalBalanceVoltage : Voltage = 0.0 [V];

    constraint leftDivider {
      leftDividerVoltage ==
        excitationVoltage * lowerLeft.actualResistance /
        (upperLeft.actualResistance + lowerLeft.actualResistance)
    }

    constraint rightDivider {
      rightDividerVoltage ==
        excitationVoltage * sensorElement.actualResistance /
        (upperRight.actualResistance + sensorElement.actualResistance)
    }

    constraint bridgeOutput {
      differentialOutputVoltage == leftDividerVoltage - rightDividerVoltage
    }

    constraint balancedWhenAllArmsEqual {
      if upperLeft.actualResistance == lowerLeft.actualResistance and
         upperRight.actualResistance == sensorElement.actualResistance then
        differentialOutputVoltage == nominalBalanceVoltage
      end
    }
  }

  part def BridgeController {
    port control : ControlPort;
    port measurementInput : MeasurementPort;
    port measurementOutput : MeasurementPort;

    attribute enabled : Boolean;
    attribute faultDetected : Boolean;
    attribute balanceThreshold : Voltage = 0.000500 [V];
    attribute lastMeasurement : BridgeMeasurement;

    action evaluateBridge {
      in measurement : BridgeMeasurement;
      out validMeasurement : BridgeMeasurement;
      out fault : Boolean;

      fault = abs(measurement.differentialOutputVoltage) > 2.5 [V];
      validMeasurement = measurement;
      lastMeasurement = measurement;
    }

    state def OperatingState {
      state off;
      state excitationStarting;
      state balancing;
      state measuring;
      state fault;

      transition initial then off;
      transition powerOn first off accept control.enableCommand if control.enableCommand == true then excitationStarting;
      transition excitationReady first excitationStarting if control.readyStatus == true then balancing;
      transition bridgeBalanced first balancing if abs(lastMeasurement.differentialOutputVoltage) <= balanceThreshold then measuring;
      transition bridgeUnbalanced first balancing if abs(lastMeasurement.differentialOutputVoltage) > balanceThreshold then measuring;
      transition faultDetected first measuring if faultDetected == true then fault;
      transition reset first fault accept control.enableCommand if control.enableCommand == false then off;
      transition powerOff first measuring accept control.enableCommand if control.enableCommand == false then off;
    }
  }

  part def WheatstoneBridgeMeasurementSystem {
    port powerControl : ControlPort;
    port measuredOutput : MeasurementPort;

    part excitation : ExcitationSource;
    part bridge : WheatstoneBridgeNetwork;
    part amplifier : DifferentialAmplifier;
    part adc : AnalogToDigitalConverter;
    part controller : BridgeController;

    connection sourcePositive connect excitation.positive to bridge.excitationPositive;
    connection sourceNegative connect excitation.negative to bridge.excitationNegative;
    connection bridgePositiveSense connect bridge.sensePositive to amplifier.inputPositive;
    connection bridgeNegativeSense connect bridge.senseNegative to amplifier.inputNegative;
    connection amplifierToAdc connect amplifier.output to adc.analogInput;
    connection adcToController connect adc.digitalOutput to controller.measurementInput;
    connection controllerToSystemOutput connect controller.measurementOutput to measuredOutput;
    connection externalControl connect powerControl to excitation.control;
    connection controllerControl connect powerControl to controller.control;

    attribute primaryFunctionDescription : String =
      "Convert a small resistance change in one arm of a Wheatstone bridge into a differential voltage measurement that can be amplified, digitized, and reported as a calibrated indication of the sensed physical quantity.";

    action measureResistanceImbalance {
      in enable : Boolean;
      out measurement : BridgeMeasurement;

      first energizeBridge;
      then acquireBridgeOutput;
      then amplify;
      then digitize;
      then publish;

      action energizeBridge {
        excitation.provideExcitation(enable, bridge.excitationVoltage);
      }

      action acquireBridgeOutput {
        measurement.excitationVoltage = bridge.excitationVoltage;
        measurement.differentialOutputVoltage = bridge.differentialOutputVoltage;
        measurement.inferredResistanceChange =
          bridge.sensorElement.actualResistance - bridge.sensorElement.resistanceAtReference;
        measurement.normalizedImbalance =
          bridge.differentialOutputVoltage / bridge.excitationVoltage;
        measurement.sensorTemperature = bridge.sensorElement.sensedTemperature;
      }

      action amplify {
        amplifier.amplifyBridgeSignal(
          bridge.leftDividerVoltage,
          bridge.rightDividerVoltage,
          measurement.differentialOutputVoltage
        );
      }

      action digitize {
        adc.sampleMeasurement(measurement, measurement);
      }

      action publish {
        controller.evaluateBridge(measurement, measurement, controller.faultDetected);
      }
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : WheatstoneBridgeMeasurementSystem;

    require constraint {
      system.bridge.differentialOutputVoltage ==
        system.bridge.leftDividerVoltage - system.bridge.rightDividerVoltage
    }
  }

  requirement def BridgeBalanceRequirement {
    subject bridge : WheatstoneBridgeNetwork;

    require constraint {
      if bridge.upperLeft.actualResistance == bridge.lowerLeft.actualResistance and
         bridge.upperRight.actualResistance == bridge.sensorElement.actualResistance then
        abs(bridge.differentialOutputVoltage) <= 0.000500 [V]
      end
    }
  }

  requirement def MeasurementOutputRequirement {
    subject system : WheatstoneBridgeMeasurementSystem;

    require constraint {
      system.measuredOutput.measurement.excitationVoltage == system.bridge.excitationVoltage and
      system.measuredOutput.measurement.differentialOutputVoltage == system.bridge.differentialOutputVoltage
    }
  }

  requirement def SafeExcitationRequirement {
    subject source : ExcitationSource;

    require constraint {
      source.outputVoltage <= 10.0 [V] and
      source.maximumCurrent <= 0.050 [A]
    }
  }

  part wheatstoneBridgeSystem : WheatstoneBridgeMeasurementSystem;

}