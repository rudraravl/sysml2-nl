package BronchitisKettle {
    import ISQ::*;
    import ScalarValues::*;
    import ScalarFunctions::*;
    import Time::*;

    // ---- Item definitions ----
    item def Water;
    item def MedicinalAdditive;
    item def TherapeuticVapor {
        attribute temperature : TemperatureValue;
        attribute additiveConcentration : Real;
    }
    item def ElectricalEnergy;

    // ---- Value types with units ----
    value type TemperatureValue :> Real { unit "K"; }
    value type VolumeValue :> Real { unit "L"; }
    value type PowerValue :> Real { unit "W"; }
    value type VoltageValue :> Real { unit "V"; }
    value type DurationValue :> Real { unit "min"; }
    value type PressureValue :> Real { unit "bar"; }
    value type MassFlowRateValue :> Real { unit "g/s"; }
    value type LevelValue :> Real { unit "mm"; }
    value type PercentageValue :> Real { unit "%"; }

    // ---- Port definitions ----
    port def WaterFlowPort {
        out item water : Water;
        attribute flowRate : MassFlowRateValue;
    }
    port def VaporFlowPort {
        out item vapor : TherapeuticVapor;
        attribute flowRate : MassFlowRateValue;
    }
    port def AdditiveIntakePort {
        in item additive : MedicinalAdditive;
    }
    port def ElectricalSupplyPort {
        in attribute voltage : VoltageValue;
        in attribute power : PowerValue;
    }
    port def HeatingPowerPort {
        out attribute commandedPower : PowerValue;
    }
    port def TemperatureSensePort {
        out attribute measuredTemperature : TemperatureValue;
    }
    port def LevelSensePort {
        out attribute measuredLevel : LevelValue;
    }
    port def PressureSensePort {
        out attribute measuredPressure : PressureValue;
    }
    port def ControlCommandPort {
        in attribute targetTemperature : TemperatureValue;
        in attribute sessionDuration : DurationValue;
        out attribute startCommand : Boolean;
        out attribute stopCommand : Boolean;
        out attribute statusMessage : String;
    }
    port def SafetyReleasePort {
        out item releasedVapor : TherapeuticVapor;
    }

    // ---- Requirements ----
    requirement def TherapeuticVaporGeneration {
        doc /* The device shall generate medicated vapor at a controlled therapeutic temperature. */
        attribute targetTemp : TemperatureValue = 368.0;
        constraint { targetTemp == 368.0 }
    }

    requirement def ReservoirCapacity {
        doc /* The water reservoir shall hold up to 2.0 L of water. */
        attribute maxCapacity : VolumeValue = 2.0;
        constraint { maxCapacity <= 2.0 }
    }

    requirement def TreatmentDuration {
        doc /* The default treatment session shall last approximately 20 minutes. */
        attribute defaultDuration : DurationValue = 20.0;
        constraint { defaultDuration == 20.0 }
    }

    requirement def OverheatProtection {
        doc /* The controller shall shut down the heating element if the boiling chamber exceeds 378 K. */
        attribute threshold : TemperatureValue = 378.0;
        constraint { threshold == 378.0 }
    }

    requirement def LowWaterProtection {
        doc /* The controller shall shut down the heating element when the boiling chamber water level falls below 5 mm. */
        attribute minLevel : LevelValue = 5.0;
        constraint { minLevel == 5.0 }
    }

    requirement def ElectricalSupply {
        doc /* The device shall operate on a standard 230 V electrical supply. */
        attribute nominalVoltage : VoltageValue = 230.0;
        constraint { nominalVoltage == 230.0 }
    }

    requirement def SafetyValveOperation {
        doc /* The safety valve shall release excess pressure above 1.5 bar. */
        attribute releasePressure : PressureValue = 1.5;
        constraint { releasePressure == 1.5 }
    }

    // ---- Part definitions ----
    part def WaterReservoir {
        attribute capacity : VolumeValue = 2.0;
        attribute currentVolume : VolumeValue;
        port waterOut : WaterFlowPort;
        exhibit state ReservoirBehavior {
            state Adequate;
            state Low;
            state Empty;
            transition Adequate to Low when currentVolume < 0.5;
            transition Low to Empty when currentVolume == 0.0;
            transition Low to Adequate when currentVolume >= 0.5;
            transition Empty to Adequate when currentVolume > 0.5;
        }
    }

    part def BoilingChamber {
        attribute volume : VolumeValue = 0.5;
        attribute currentTemperature : TemperatureValue;
        attribute currentLevel : LevelValue;
        attribute currentPressure : PressureValue;
        port waterIn : WaterFlowPort;
        port additiveIn : AdditiveIntakePort;
        port vaporOut : VaporFlowPort;
        port tempSense : TemperatureSensePort;
        port levelSense : LevelSensePort;
        port pressureSense : PressureSensePort;
        port safetyRelease : SafetyReleasePort;
    }

    part def HeatingElement {
        attribute maxPower : PowerValue = 1500.0;
        attribute commandedPower : PowerValue;
        port powerIn : ElectricalSupplyPort;
        port powerOut : HeatingPowerPort;
        exhibit state HeatingState {
            state Off;
            state On;
            transition Off to On when commandedPower > 0.0;
            transition On to Off when commandedPower == 0.0;
        }
    }

    part def TemperatureSensor {
        attribute measuredTemperature : TemperatureValue;
        port senseOut : TemperatureSensePort;
        action def measure : TemperatureValue;
    }

    part def LevelSensor {
        attribute measuredLevel : LevelValue;
        port senseOut : LevelSensePort;
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port senseOut : PressureSensePort;
    }

    part def SafetyValve {
        attribute releaseThreshold : PressureValue = 1.5;
        port releasePort : SafetyReleasePort;
        exhibit state ValveState {
            state Closed;
            state Open;
            transition Closed to Open when releasePort.releasedVapor.temperature > 0.0;
            transition Open to Closed when releasePort.releasedVapor.temperature == 0.0;
        }
    }

    part def VaporizationNozzle {
        attribute outputFlowRate : MassFlowRateValue;
        port vaporIn : VaporFlowPort;
        port vaporOut : VaporFlowPort;
    }

    part def ControlInterface {
        attribute targetTemperature : TemperatureValue = 368.0;
        attribute sessionDuration : DurationValue = 20.0;
        port userCommand : ControlCommandPort;
        action def setTarget(temp : TemperatureValue) : TemperatureValue;
        action def setDuration(d : DurationValue) : DurationValue;
    }

    part def ControllerUnit {
        attribute targetTemperature : TemperatureValue = 368.0;
        attribute sessionDuration : DurationValue = 20.0;
        attribute overheatThreshold : TemperatureValue = 378.0;
        attribute lowWaterThreshold : LevelValue = 5.0;
        attribute active : Boolean = false;
        attribute elapsed : DurationValue = 0.0;

        port tempInput : TemperatureSensePort;
        port levelInput : LevelSensePort;
        port pressureInput : PressureSensePort;
        port powerOutput : HeatingPowerPort;
        port interfacePort : ControlCommandPort;

        exhibit state ControllerStateMachine {
            entry; then Idle;
            state Idle {
                entry { active = false; powerOutput.commandedPower = 0.0; }
            }
            state Heating {
                entry { active = true; }
                do action regulatePower {
                    if tempInput.measuredTemperature < targetTemperature {
                        powerOutput.commandedPower = 1500.0;
                    } else {
                        powerOutput.commandedPower = 200.0;
                    }
                }
            }
            state Therapeutic {
                do action maintainTemperature {
                    powerOutput.commandedPower = 300.0;
                }
            }
            state Shutdown {
                entry { active = false; powerOutput.commandedPower = 0.0; }
            }
            state Alarm {
                entry { powerOutput.commandedPower = 0.0; interfacePort.statusMessage = "Alarm"; }
            }
            transition Idle to Heating when interfacePort.startCommand == true;
            transition Heating to Therapeutic when tempInput.measuredTemperature >= targetTemperature;
            transition Therapeutic to Shutdown when elapsed >= sessionDuration;
            transition Heating to Alarm when tempInput.measuredTemperature > overheatThreshold;
            transition Therapeutic to Alarm when tempInput.measuredTemperature > overheatThreshold;
            transition Heating to Alarm when levelInput.measuredLevel < lowWaterThreshold;
            transition Therapeutic to Alarm when levelInput.measuredLevel < lowWaterThreshold;
            transition Shutdown to Idle when interfacePort.stopCommand == true;
            transition Alarm to Idle when interfacePort.stopCommand == true;
        }
    }

    part def BronchitisKettleDevice {
        satisfy TherapeuticVaporGeneration;
        satisfy ReservoirCapacity;
        satisfy TreatmentDuration;
        satisfy OverheatProtection;
        satisfy LowWaterProtection;
        satisfy ElectricalSupply;
        satisfy SafetyValveOperation;

        attribute supplyVoltage : VoltageValue = 230.0;

        part reservoir : WaterReservoir {
            attribute currentVolume : VolumeValue = 2.0;
        }
        part boiler : BoilingChamber {
            attribute currentTemperature : TemperatureValue = 293.0;
            attribute currentLevel : LevelValue = 0.0;
            attribute currentPressure : PressureValue = 1.0;
        }
        part heater : HeatingElement {
            attribute commandedPower : PowerValue = 0.0;
        }
        part tempSensor : TemperatureSensor;
        part levelSensor : LevelSensor;
        part pressureSensor : PressureSensor;
        part safetyValve : SafetyValve;
        part nozzle : VaporizationNozzle;
        part interface : ControlInterface;
        part controller : ControllerUnit;

        port mainsSupply : ElectricalSupplyPort;
        port userAdditiveIntake : AdditiveIntakePort;
        port userVaporOutlet : VaporFlowPort;

        connection waterSupply connect reservoir.waterOut to boiler.waterIn;
        connection additiveSupply connect userAdditiveIntake to boiler.additiveIn;
        connection vaporPath connect boiler.vaporOut to nozzle.vaporIn;
        connection vaporOutlet connect nozzle.vaporOut to userVaporOutlet;
        connection tempFeedback connect boiler.tempSense to controller.tempInput;
        connection levelFeedback connect boiler.levelSense to controller.levelInput;
        connection pressureFeedback connect boiler.pressureSense to controller.pressureInput;
        connection powerCommand connect controller.powerOutput to heater.powerOut;
        connection mainsPower connect mainsSupply to heater.powerIn;
        connection interfaceLink connect interface.userCommand to controller.interfacePort;
        connection safetyReleasePath connect boiler.safetyRelease to safetyValve.releasePort;

        exhibit action def startupSequence {
            action fillBoiler {
                boiler.currentLevel = 50.0;
            }
            action preheat {
                controller.interfacePort.startCommand = true;
            }
        }
    }
}
