package BimetallicThermostat {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    value type Temperature :> Real {
        :>> unit = K;
    }

    value type TemperatureDifference :> Real {
        :>> unit = K;
    }

    value type Length :> Real {
        :>> unit = m;
    }

    value type Force :> Real {
        :>> unit = N;
    }

    value type Voltage :> Real {
        :>> unit = V;
    }

    value type Current :> Real {
        :>> unit = A;
    }

    value type Resistance :> Real {
        :>> unit = Ohm;
    }

    value type ExpansionCoefficient :> Real {
        :>> unit = 1/K;
    }

    value type Curvature :> Real {
        :>> unit = 1/m;
    }

    value type Angle :> Real {
        :>> unit = rad;
    }

    value type Pressure :> Real {
        :>> unit = Pa;
    }

    value type TimeValue :> Real {
        :>> unit = s;
    }

    item def HeatFlow;
    item def ElectricalEnergy;
    item def MechanicalMotion;

    port def ThermalPort {
        attribute temperature : Temperature;
        in item heat : HeatFlow;
    }

    port def ElectricalPort {
        attribute voltage : Voltage;
        attribute current : Current;
        in item energy : ElectricalEnergy;
    }

    port def MechanicalPort {
        attribute displacement : Length;
        attribute force : Force;
        in item motion : MechanicalMotion;
    }

    part def MetalLayer {
        attribute materialName : String;
        attribute thickness : Length;
        attribute expansionCoefficient : ExpansionCoefficient;
        attribute elasticModulus : Pressure;
        port thermalInterface : ThermalPort;
    }

    part def BimetallicStrip {
        attribute setpoint : Temperature = 333.15 [K];
        attribute hysteresis : TemperatureDifference = 3 [K];
        attribute stripLength : Length = 0.04 [m];
        attribute stripWidth : Length = 0.008 [m];
        attribute referenceTemperature : Temperature = 293.15 [K];
        attribute currentTemperature : Temperature = 293.15 [K];
        attribute currentCurvature : Curvature = 0 [1/m];
        attribute tipDisplacement : Length = 0 [m];
        attribute bendingAngle : Angle = 0 [rad];
        attribute deltaTemperature : TemperatureDifference = 0 [K];

        part highExpansionLayer : MetalLayer {
            :>> materialName = "Brass";
            :>> thickness = 0.0005 [m];
            :>> expansionCoefficient = 20e-6 [1/K];
            :>> elasticModulus = 100e9 [Pa];
        }

        part lowExpansionLayer : MetalLayer {
            :>> materialName = "Invar";
            :>> thickness = 0.0005 [m];
            :>> expansionCoefficient = 1.2e-6 [1/K];
            :>> elasticModulus = 140e9 [Pa];
        }

        port ambientThermal : ThermalPort;
        port mechanicalOutput : MechanicalPort;

        connection thermalBond connect highExpansionLayer.thermalInterface to lowExpansionLayer.thermalInterface;

        action def ComputeCurvature {
            in temperature : Temperature;
            in refTemp : Temperature;
            in alphaHigh : ExpansionCoefficient;
            in alphaLow : ExpansionCoefficient;
            in totalThickness : Length;
            in stripLen : Length;
            out curvature : Curvature;
            out displacement : Length;
            out bendAngle : Angle;
        }

        action def UpdateTemperature {
            in ambientTemp : Temperature;
            out newTemp : Temperature;
            out deltaT : TemperatureDifference;
        }

        action computeBending : ComputeCurvature;
        action updateTemp : UpdateTemperature;
    }

    part def ElectricalContact {
        attribute isFixed : Boolean;
        attribute contactPosition : Length;
        attribute contactResistance : Resistance;
        attribute contactDiameter : Length;
        port electricalConnection : ElectricalPort;
    }

    part def SwitchMechanism {
        attribute contactGap : Length = 0.0008 [m];
        attribute isClosed : Boolean = false;
        attribute closingForce : Force = 0.5 [N];
        attribute openingForce : Force = 0.2 [N];
        attribute maxContactResistance : Resistance = 0.05 [Ohm];

        part movableContact : ElectricalContact {
            :>> isFixed = false;
            :>> contactPosition = 0 [m];
            :>> contactResistance = 0.01 [Ohm];
            :>> contactDiameter = 0.003 [m];
        }

        part fixedContact : ElectricalContact {
            :>> isFixed = true;
            :>> contactPosition = 0.0008 [m];
            :>> contactResistance = 0.01 [Ohm];
            :>> contactDiameter = 0.003 [m];
        }

        port lineIn : ElectricalPort;
        port lineOut : ElectricalPort;
        port mechanicalInput : MechanicalPort;

        connection inputWire connect lineIn to movableContact.electricalConnection;
        connection contactBridge connect movableContact.electricalConnection to fixedContact.electricalConnection;
        connection outputWire connect fixedContact.electricalConnection to lineOut;

        action def CloseContacts {
            in displacement : Length;
            in gap : Length;
            in force : Force;
            out closed : Boolean;
        }

        action def OpenContacts {
            in displacement : Length;
            in force : Force;
            out closed : Boolean;
        }

        action closeAction : CloseContacts;
        action openAction : OpenContacts;
    }

    part def BimetallicThermostatDevice {
        attribute deviceSetpoint : Temperature = 333.15 [K];
        attribute deviceHysteresis : TemperatureDifference = 3 [K];
        attribute ratedVoltage : Voltage = 250 [V];
        attribute ratedCurrent : Current = 16 [A];
        attribute operatingTempMin : Temperature = 233.15 [K];
        attribute operatingTempMax : Temperature = 423.15 [K];
        attribute responseTime : TimeValue = 30 [s];
        attribute mechanicalLifeCycles : Integer = 100000;

        part sensingStrip : BimetallicStrip {
            :>> setpoint = 333.15 [K];
            :>> hysteresis = 3 [K];
            :>> stripLength = 0.04 [m];
            :>> stripWidth = 0.008 [m];
            :>> referenceTemperature = 293.15 [K];
        }

        part switch : SwitchMechanism {
            :>> contactGap = 0.0008 [m];
            :>> closingForce = 0.5 [N];
            :>> openingForce = 0.2 [N];
        }

        port ambientThermal : ThermalPort;
        port electricalIn : ElectricalPort;
        port electricalOut : ElectricalPort;

        connection thermalInput connect ambientThermal to sensingStrip.ambientThermal;
        connection mechanicalLink connect sensingStrip.mechanicalOutput to switch.mechanicalInput;
        connection powerIn connect electricalIn to switch.lineIn;
        connection powerOut connect switch.lineOut to electricalOut;

        exhibit state def SwitchingBehavior {
            attribute upperThreshold : Temperature = deviceSetpoint + deviceHysteresis;
            attribute lowerThreshold : Temperature = deviceSetpoint - deviceHysteresis;

            entry; then Open;

            state Open {
                doc /* Circuit is open; contacts are separated. */
                entry;

                transition to Closed
                    when sensingStrip.currentTemperature >= upperThreshold;
            }

            state Closed {
                doc /* Circuit is closed; contacts are touching. */
                entry;

                transition to Open
                    when sensingStrip.currentTemperature <= lowerThreshold;
            }
        }
    }

    requirement def SetpointAccuracyRequirement {
        doc /* The thermostat shall switch at the specified setpoint within the defined tolerance. */
        subject device : BimetallicThermostatDevice;
        attribute tolerance : TemperatureDifference = 2 [K];
        requirement {
            device.sensingStrip.currentTemperature >= device.deviceSetpoint - tolerance and
            device.sensingStrip.currentTemperature <= device.deviceSetpoint + tolerance
        }
    }

    requirement def HysteresisRangeRequirement {
        doc /* The thermostat shall incorporate hysteresis to prevent rapid cycling. */
        subject device : BimetallicThermostatDevice;
        attribute minHysteresis : TemperatureDifference = 1 [K];
        attribute maxHysteresis : TemperatureDifference = 10 [K];
        requirement {
            device.deviceHysteresis >= minHysteresis and
            device.deviceHysteresis <= maxHysteresis
        }
    }

    requirement def SwitchingActionRequirement {
        doc /* The switch shall close when temperature exceeds upper threshold and open when temperature falls below lower threshold. */
        subject device : BimetallicThermostatDevice;
        requirement {
            (device.sensingStrip.currentTemperature >= device.deviceSetpoint + device.deviceHysteresis)
            implies device.switch.isClosed == true
        }
        requirement {
            (device.sensingStrip.currentTemperature <= device.deviceSetpoint - device.deviceHysteresis)
            implies device.switch.isClosed == false
        }
    }

    requirement def PassiveOperationRequirement {
        doc /* The device shall operate without external power; sensing and actuation are powered solely by thermal expansion of the bimetallic strip. */
        subject device : BimetallicThermostatDevice;
        requirement {
            device.sensingStrip.highExpansionLayer.expansionCoefficient >
            device.sensingStrip.lowExpansionLayer.expansionCoefficient
        }
    }

    requirement def ElectricalRatingRequirement {
        doc /* The thermostat shall be rated for at least 250 V and 16 A. */
        subject device : BimetallicThermostatDevice;
        attribute minVoltage : Voltage = 250 [V];
        attribute minCurrent : Current = 16 [A];
        requirement {
            device.ratedVoltage >= minVoltage and
            device.ratedCurrent >= minCurrent
        }
    }

    requirement def OperatingTemperatureRequirement {
        doc /* The thermostat shall operate within the specified ambient temperature range. */
        subject device : BimetallicThermostatDevice;
        requirement {
            device.sensingStrip.currentTemperature >= device.operatingTempMin and
            device.sensingStrip.currentTemperature <= device.operatingTempMax
        }
    }

    requirement def ContactGapRequirement {
        doc /* The contact gap shall be small enough to be bridged by the bimetallic strip deflection. */
        subject device : BimetallicThermostatDevice;
        attribute maxGap : Length = 0.002 [m];
        requirement {
            device.switch.contactGap <= maxGap
        }
    }

    requirement def BimetallicDifferentialExpansionRequirement {
        doc /* The two metal layers shall have significantly different coefficients of thermal expansion. */
        subject device : BimetallicThermostatDevice;
        attribute minRatio : Real = 5.0;
        requirement {
            device.sensingStrip.highExpansionLayer.expansionCoefficient /
            device.sensingStrip.lowExpansionLayer.expansionCoefficient >= minRatio
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The thermostat shall respond to temperature changes within the specified time. */
        subject device : BimetallicThermostatDevice;
        attribute maxResponseTime : TimeValue = 60 [s];
        requirement {
            device.responseTime <= maxResponseTime
        }
    }

    part def ThermostatSystem {
        part thermostat : BimetallicThermostatDevice;

        satisfy SetpointAccuracyRequirement by thermostat;
        satisfy HysteresisRangeRequirement by thermostat;
        satisfy SwitchingActionRequirement by thermostat;
        satisfy PassiveOperationRequirement by thermostat;
        satisfy ElectricalRatingRequirement by thermostat;
        satisfy OperatingTemperatureRequirement by thermostat;
        satisfy ContactGapRequirement by thermostat;
        satisfy BimetallicDifferentialExpansionRequirement by thermostat;
        satisfy ResponseTimeRequirement by thermostat;
    }
}
