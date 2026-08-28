package CentralHeatingSystem {
    import ScalarValues::*;

    value type Temperature :> Real { unit "degC"; }
    value type Power :> Real { unit "kW"; }
    value type Percentage :> Real { unit "%"; }
    value type FlowRate :> Real { unit "L/min"; }
    value type Pressure :> Real { unit "bar"; }
    value type TimeInterval :> Real { unit "s"; }

    enumeration def FaultCode {
        none;
        ignitionFailure;
        flameLoss;
        overheat;
        lowWaterPressure;
        sensorFault;
    }

    enumeration def BoilerOperationalStatus {
        standby;
        heating;
        fault;
    }

    item def OpenThermMessage {
        attribute messageID : Integer;
        attribute payload : Integer;
    }

    item def SetpointCommand :> OpenThermMessage {
        attribute targetWaterTemp : Temperature;
        attribute enableHeating : Boolean;
        attribute roomSetpoint : Temperature;
    }

    item def BoilerStatusMessage :> OpenThermMessage {
        attribute currentWaterTemp : Temperature;
        attribute modulationLevel : Percentage;
        attribute flameActive : Boolean;
        attribute faultCode : FaultCode;
        attribute status : BoilerOperationalStatus;
    }

    port def OpenThermMasterPort {
        out item setpointCommand : SetpointCommand;
        in item boilerStatus : BoilerStatusMessage;
    }

    port def OpenThermSlavePort {
        in item setpointCommand : SetpointCommand;
        out item boilerStatus : BoilerStatusMessage;
    }

    port def AmbientTempSensorPort {
        out item measuredTemp : Temperature;
    }

    port def UserInterfacePort {
        in attribute desiredTemp : Temperature;
        out attribute currentTempDisplay : Temperature;
        out attribute boilerModulationDisplay : Percentage;
        out attribute faultDisplay : FaultCode;
    }

    port def HeatingCircuitPort {
        out item supplyWaterTemp : Temperature;
        out item returnWaterTemp : Temperature;
        in item flowRate : FlowRate;
    }

    port def FuelSupplyPort {
        in item fuelFlowRate : FlowRate;
    }

    requirement def TemperatureControlRequirement {
        doc /* The system shall maintain room temperature within +/- 0.5 degC of the user setpoint. */
        attribute tolerance : Temperature default 0.5;
    }

    requirement def ModulationRequirement {
        doc /* The boiler shall modulate power output between minimum and maximum modulation levels. */
        attribute minModulation : Percentage default 20.0;
        attribute maxModulation : Percentage default 100.0;
    }

    requirement def CommunicationRequirement {
        doc /* The thermostat shall transmit setpoint commands and receive status updates continuously via OpenTherm. */
        attribute updateInterval : TimeInterval default 1.0;
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall achieve at least 15 percent energy savings compared to on/off boiler control. */
        attribute minSavings : Percentage default 15.0;
    }

    requirement def SafetyRequirement {
        doc /* The boiler shall shut down the burner immediately if a fault condition is detected. */
    }

    action def ComputeTargetWaterTemp {
        in roomSetpoint : Temperature;
        in measuredTemp : Temperature;
        in prevIntegral : Real;
        in proportionalGain : Real;
        in integralGain : Real;
        out targetWaterTemp : Temperature;
        out newIntegral : Real;

        local error : Temperature;
        local rawTarget : Temperature;

        error = roomSetpoint - measuredTemp;
        newIntegral = prevIntegral + error;
        rawTarget = 35.0 + proportionalGain * error + integralGain * newIntegral;

        if rawTarget > 80.0 {
            targetWaterTemp = 80.0;
        } else if rawTarget < 20.0 {
            targetWaterTemp = 20.0;
        } else {
            targetWaterTemp = rawTarget;
        }
    }

    action def AdjustBurner {
        in targetTemp : Temperature;
        in currentTemp : Temperature;
        in minMod : Percentage;
        in maxMod : Percentage;
        out modulation : Percentage;
        out flameActive : Boolean;

        local delta : Temperature;
        delta = targetTemp - currentTemp;

        if delta > 10.0 {
            modulation = maxMod;
            flameActive = true;
        } else if delta > 5.0 {
            modulation = 75.0;
            flameActive = true;
        } else if delta > 2.0 {
            modulation = 50.0;
            flameActive = true;
        } else if delta > 0.5 {
            modulation = minMod;
            flameActive = true;
        } else {
            modulation = 0.0;
            flameActive = false;
        }
    }

    action def PublishBoilerStatus {
        in currentWaterTemp : Temperature;
        in modulationLevel : Percentage;
        in flame : Boolean;
        in fault : FaultCode;
        in opStatus : BoilerOperationalStatus;
        out statusMsg : BoilerStatusMessage;

        statusMsg.currentWaterTemp = currentWaterTemp;
        statusMsg.modulationLevel = modulationLevel;
        statusMsg.flameActive = flame;
        statusMsg.faultCode = fault;
        statusMsg.status = opStatus;
    }

    part def AmbientSensor {
        attribute currentReading : Temperature default 20.0;
        port sensorOut : AmbientTempSensorPort;

        do {
            sensorOut.measuredTemp = currentReading;
        }
    }

    part def UserInterface {
        attribute setpoint : Temperature default 21.0;
        attribute displayTemp : Temperature;
        attribute displayModulation : Percentage;
        attribute displayFault : FaultCode;
        port uiPort : UserInterfacePort;

        do {
            uiPort.desiredTemp = setpoint;
            displayTemp = uiPort.currentTempDisplay;
            displayModulation = uiPort.boilerModulationDisplay;
            displayFault = uiPort.faultDisplay;
        }
    }

    part def RoomThermostat {
        attribute desiredTemperature : Temperature default 21.0;
        attribute measuredTemperature : Temperature default 20.0;
        attribute targetWaterTemp : Temperature default 35.0;
        attribute integralTerm : Real default 0.0;
        attribute proportionalGain : Real default 2.0;
        attribute integralGain : Real default 0.1;
        attribute lastBoilerStatus : BoilerStatusMessage;
        attribute controlError : Temperature;
        attribute rawTarget : Temperature;

        port masterPort : OpenThermMasterPort;
        port sensorPort : AmbientTempSensorPort;
        port uiPort : UserInterfacePort;

        state thermostatStateMachine {
            entry; then monitoring;

            state monitoring {
                entry {
                    measuredTemperature = sensorPort.measuredTemp;
                    controlError = desiredTemperature - measuredTemperature;
                }
                do {
                    integralTerm = integralTerm + controlError;
                    rawTarget = 35.0 + proportionalGain * controlError + integralGain * integralTerm;
                    if rawTarget > 80.0 {
                        targetWaterTemp = 80.0;
                    } else if rawTarget < 20.0 {
                        targetWaterTemp = 20.0;
                    } else {
                        targetWaterTemp = rawTarget;
                    }
                }
            }

            transition monitoring -> commanding
                when controlError > 0.5;

            state commanding {
                entry {
                    masterPort.setpointCommand.targetWaterTemp = targetWaterTemp;
                    masterPort.setpointCommand.enableHeating = true;
                    masterPort.setpointCommand.roomSetpoint = desiredTemperature;
                }
                do {
                    lastBoilerStatus = masterPort.boilerStatus;
                    uiPort.currentTempDisplay = measuredTemperature;
                    uiPort.boilerModulationDisplay = lastBoilerStatus.modulationLevel;
                    uiPort.faultDisplay = lastBoilerStatus.faultCode;
                }
            }

            transition commanding -> monitoring
                when lastBoilerStatus.flameActive == true;

            transition monitoring -> idle
                when controlError <= 0.0;

            state idle {
                entry {
                    masterPort.setpointCommand.enableHeating = false;
                    masterPort.setpointCommand.targetWaterTemp = 20.0;
                }
                do {
                    lastBoilerStatus = masterPort.boilerStatus;
                    uiPort.currentTempDisplay = measuredTemperature;
                    uiPort.boilerModulationDisplay = 0.0;
                    uiPort.faultDisplay = lastBoilerStatus.faultCode;
                }
            }

            transition idle -> monitoring
                when controlError > 0.5;
        }
    }

    part def ModulatingBoiler {
        attribute ratedPower : Power default 24.0;
        attribute minModulation : Percentage default 20.0;
        attribute maxModulation : Percentage default 100.0;
        attribute currentModulation : Percentage default 0.0;
        attribute currentWaterTemp : Temperature default 20.0;
        attribute targetWaterTemp : Temperature default 35.0;
        attribute flameActive : Boolean default false;
        attribute faultCode : FaultCode default none;
        attribute operationalStatus : BoilerOperationalStatus default standby;
        attribute maxWaterTemp : Temperature default 85.0;
        attribute deltaT : Temperature;
        attribute heatingEnabled : Boolean default false;

        port slavePort : OpenThermSlavePort;
        port heatingPort : HeatingCircuitPort;
        port fuelPort : FuelSupplyPort;

        state boilerStateMachine {
            entry; then standby;

            state standby {
                entry {
                    flameActive = false;
                    currentModulation = 0.0;
                    operationalStatus = standby;
                }
                do {
                    slavePort.boilerStatus.currentWaterTemp = currentWaterTemp;
                    slavePort.boilerStatus.modulationLevel = currentModulation;
                    slavePort.boilerStatus.flameActive = flameActive;
                    slavePort.boilerStatus.faultCode = faultCode;
                    slavePort.boilerStatus.status = operationalStatus;
                }
            }

            transition standby -> heating
                when slavePort.setpointCommand.enableHeating == true;

            state heating {
                entry {
                    targetWaterTemp = slavePort.setpointCommand.targetWaterTemp;
                    operationalStatus = heating;
                    heatingEnabled = true;
                }
                do {
                    deltaT = targetWaterTemp - currentWaterTemp;

                    if deltaT > 10.0 {
                        currentModulation = maxModulation;
                        flameActive = true;
                    } else if deltaT > 5.0 {
                        currentModulation = 75.0;
                        flameActive = true;
                    } else if deltaT > 2.0 {
                        currentModulation = 50.0;
                        flameActive = true;
                    } else if deltaT > 0.5 {
                        currentModulation = minModulation;
                        flameActive = true;
                    } else {
                        currentModulation = 0.0;
                        flameActive = false;
                    }

                    if flameActive {
                        currentWaterTemp = currentWaterTemp + 0.05 * (currentModulation / 100.0);
                    }

                    if currentWaterTemp > maxWaterTemp {
                        faultCode = overheat;
                    }

                    slavePort.boilerStatus.currentWaterTemp = currentWaterTemp;
                    slavePort.boilerStatus.modulationLevel = currentModulation;
                    slavePort.boilerStatus.flameActive = flameActive;
                    slavePort.boilerStatus.faultCode = faultCode;
                    slavePort.boilerStatus.status = operationalStatus;

                    heatingPort.supplyWaterTemp = currentWaterTemp;
                    heatingPort.returnWaterTemp = currentWaterTemp - 10.0;
                }
            }

            transition heating -> standby
                when slavePort.setpointCommand.enableHeating == false;

            transition heating -> faultState
                when faultCode != none;

            state faultState {
                entry {
                    flameActive = false;
                    currentModulation = 0.0;
                    operationalStatus = fault;
                    heatingEnabled = false;
                }
                do {
                    slavePort.boilerStatus.faultCode = faultCode;
                    slavePort.boilerStatus.status = operationalStatus;
                    slavePort.boilerStatus.flameActive = false;
                    slavePort.boilerStatus.modulationLevel = 0.0;
                    slavePort.boilerStatus.currentWaterTemp = currentWaterTemp;
                }
            }

            transition faultState -> standby
                when faultCode == none;
        }
    }

    part def CentralHeatingSystem {
        attribute systemActive : Boolean default true;
        attribute ambientTemperature : Temperature default 20.0;

        part thermostat : RoomThermostat {
            attribute desiredTemperature = 21.0;
            attribute proportionalGain = 2.0;
            attribute integralGain = 0.1;
        }

        part boiler : ModulatingBoiler {
            attribute ratedPower = 24.0;
            attribute minModulation = 20.0;
            attribute maxModulation = 100.0;
        }

        part ambientSensor : AmbientSensor {
            attribute currentReading = 20.0;
        }

        part userInterface : UserInterface {
            attribute setpoint = 21.0;
        }

        connection thermostat.masterPort <> boiler.slavePort;
        connection ambientSensor.sensorOut <> thermostat.sensorPort;
        connection userInterface.uiPort <> thermostat.uiPort;

        satisfy TemperatureControlRequirement by thermostat;
        satisfy ModulationRequirement by boiler;
        satisfy CommunicationRequirement by thermostat.masterPort;
        satisfy EnergyEfficiencyRequirement by CentralHeatingSystem;
        satisfy SafetyRequirement by boiler;
    }
}
