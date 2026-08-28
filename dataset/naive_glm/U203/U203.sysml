package HeartLungMachine {
    import ScalarValues::*;
    import Collections::*;

    // ===== Value Types =====
    value type VolumeFlowRate > Real { unit 'mL/min'; }
    value type Pressure > Real { unit 'mmHg'; }
    value type Temperature > Real { unit 'degC'; }
    value type Volume > Real { unit 'mL'; }
    value type OxygenSaturation > Real { unit '%'; }
    value type RotationalSpeed > Real { unit 'rpm'; }
    value type Duration > Real { unit 'min'; }
    value type Power > Real { unit 'W'; }

    // ===== Item Types =====
    item def Blood {
        attribute temperature : Temperature;
        attribute oxygenSaturation : OxygenSaturation;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
        attribute volume : Volume;
    }

    item def DeoxygenatedBlood :> Blood {
        constraint { oxygenSaturation < 75.0; }
    }

    item def OxygenatedBlood :> Blood {
        constraint { oxygenSaturation >= 95.0; }
    }

    item def OxygenGas;
    item def CarbonDioxideGas;
    item def DebrisParticle;
    item def AirBubble;

    // ===== Port Definitions =====
    port def BloodInPort {
        in item blood : Blood;
    }
    port def BloodOutPort {
        out item blood : Blood;
    }
    port def GasInPort {
        in item gas : OxygenGas;
    }
    port def GasOutPort {
        out item gas : CarbonDioxideGas;
    }
    port def SignalOutPort {
        out attribute flowRate : VolumeFlowRate;
        out attribute pressure : Pressure;
        out attribute temperature : Temperature;
        out attribute oxygenSaturation : OxygenSaturation;
    }
    port def SignalInPort {
        in attribute flowRate : VolumeFlowRate;
        in attribute pressure : Pressure;
        in attribute temperature : Temperature;
        in attribute oxygenSaturation : OxygenSaturation;
    }

    // ===== Requirements =====
    requirement def CardiopulmonaryBypassRequirement {
        doc "The system shall temporarily take over the complete function of the patient's heart and lungs during open-heart surgery."
        attribute targetFlowRate : VolumeFlowRate = 5000.0;
        attribute targetOxygenSaturation : OxygenSaturation = 98.0;
        attribute targetTemperature : Temperature = 37.0;
        constraint { flowRate >= targetFlowRate; }
        constraint { oxygenSaturation >= 95.0; }
        constraint { temperature >= 32.0 and temperature <= 37.0; }
    }

    requirement def OxygenationRequirement {
        doc "The Bubble Oxygenator shall raise blood oxygen saturation to at least 95% and release carbon dioxide."
        attribute minOxygenSaturation : OxygenSaturation = 95.0;
        constraint { oxygenSaturation >= minOxygenSaturation; }
    }

    requirement def TemperatureControlRequirement {
        doc "The Heat Exchanger shall control blood temperature between 18 degC and 37 degC as required by surgery."
        attribute minTemp : Temperature = 18.0;
        attribute maxTemp : Temperature = 37.0;
        constraint { temperature >= minTemp and temperature <= maxTemp; }
    }

    requirement def FiltrationRequirement {
        doc "The Blood Filter shall remove debris particles and air bubbles before blood is returned to the patient."
        constraint { debrisCount == 0; }
        constraint { airBubbleCount == 0; }
    }

    requirement def MonitoringRequirement {
        doc "The Monitoring Console shall continuously display blood flow rate, pressure, temperature, and oxygen saturation."
        attribute updateInterval : Duration = 0.5;
    }

    // ===== Parts =====
    part def VenousCannula {
        attribute diameter : Real = 12.0;
        port venousIn : BloodInPort;
        port venousOut : BloodOutPort;
        attribute extractedFlow : VolumeFlowRate;
        action def DrainBlood {
            in item deoxyBlood : DeoxygenatedBlood;
            out item drainedBlood : DeoxygenatedBlood;
        }
        perform DrainBlood;
    }

    part def VenousReservoir {
        attribute capacity : Volume = 3000.0;
        attribute currentVolume : Volume;
        port reservoirIn : BloodInPort;
        port reservoirOut : BloodOutPort;
        action def BufferBlood {
            in item incoming : DeoxygenatedBlood;
            in out item stored : DeoxygenatedBlood;
        }
        perform BufferBlood;
        constraint { currentVolume <= capacity; }
    }

    part def RollerPump {
        attribute rotationSpeed : RotationalSpeed = 100.0;
        attribute maxFlowRate : VolumeFlowRate = 6000.0;
        attribute powerConsumption : Power;
        port pumpIn : BloodInPort;
        port pumpOut : BloodOutPort;
        action def PropelBlood {
            in item bloodIn : Blood;
            out item bloodOut : Blood;
            constraint { bloodOut.flowRate <= maxFlowRate; }
        }
        perform PropelBlood;
    }

    part def BubbleOxygenator {
        attribute oxygenFlowRate : VolumeFlowRate = 5000.0;
        attribute heatLoss : Power;
        port oxygenatorIn : BloodInPort;
        port oxygenatorOut : BloodOutPort;
        port gasSupply : GasInPort;
        port gasExhaust : GasOutPort;
        action def OxygenateBlood {
            in item deoxyBlood : DeoxygenatedBlood;
            in item oxygen : OxygenGas;
            out item oxyBlood : OxygenatedBlood;
            out item co2 : CarbonDioxideGas;
            constraint { oxyBlood.oxygenSaturation >= 95.0; }
        }
        perform OxygenateBlood;
        satisfy OxygenationRequirement;
    }

    part def HeatExchangerUnit {
        attribute targetTemperature : Temperature = 37.0;
        attribute heatingPower : Power;
        port exchangerIn : BloodInPort;
        port exchangerOut : BloodOutPort;
        action def RegulateTemperature {
            in item bloodIn : Blood;
            in attribute setPoint : Temperature;
            out item bloodOut : Blood;
            constraint { bloodOut.temperature == setPoint; }
        }
        perform RegulateTemperature;
        satisfy TemperatureControlRequirement;
    }

    part def BloodFilter {
        attribute poreSize : Real = 40.0;
        port filterIn : BloodInPort;
        port filterOut : BloodOutPort;
        action def FilterBlood {
            in item bloodIn : Blood;
            in out item debris : DebrisParticle[*];
            in out item air : AirBubble[*];
            out item bloodOut : Blood;
        }
        perform FilterBlood;
        satisfy FiltrationRequirement;
    }

    part def ArterialCannula {
        attribute diameter : Real = 10.0;
        port arterialIn : BloodInPort;
        port arterialOut : BloodOutPort;
        action def ReturnBlood {
            in item oxyBlood : OxygenatedBlood;
            out item returnedBlood : OxygenatedBlood;
        }
        perform ReturnBlood;
    }

    part def MonitoringConsole {
        attribute displayFlowRate : VolumeFlowRate;
        attribute displayPressure : Pressure;
        attribute displayTemperature : Temperature;
        attribute displayOxygenSaturation : OxygenSaturation;
        port sensorInput : SignalInPort;
        action def DisplayParameters {
            in attribute flowRate : VolumeFlowRate;
            in attribute pressure : Pressure;
            in attribute temperature : Temperature;
            in attribute oxygenSaturation : OxygenSaturation;
        }
        perform DisplayParameters;
        satisfy MonitoringRequirement;
    }

    part def Patient {
        attribute bodyWeight : Real = 70.0;
        port venousDrainage : BloodOutPort;
        port arterialReturn : BloodInPort;
        state def PhysiologicalState {
            entry; then OnBypass;
            state OnBypass;
            state OffBypass;
        }
        exhibit PhysiologicalState;
    }

    // ===== System =====
    part def HeartLungMachine {
        port patientVenousConnection : BloodInPort;
        port patientArterialConnection : BloodOutPort;
        port consoleInterface : SignalOutPort;

        part venousCannula : VenousCannula;
        part venousReservoir : VenousReservoir;
        part rollerPump : RollerPump;
        part bubbleOxygenator : BubbleOxygenator;
        part heatExchanger : HeatExchangerUnit;
        part bloodFilter : BloodFilter;
        part arterialCannula : ArterialCannula;
        part monitoringConsole : MonitoringConsole;

        connection def BloodConnection {
            end :>> source : BloodOutPort;
            end :>> target : BloodInPort;
            flow bloodFlow : Blood from source.blood to target.blood;
        }

        connection patientToCannula : BloodConnection
            connect patientVenousConnection to venousCannula.venousIn;
        connection cannulaToReservoir : BloodConnection
            connect venousCannula.venousOut to venousReservoir.reservoirIn;
        connection reservoirToPump : BloodConnection
            connect venousReservoir.reservoirOut to rollerPump.pumpIn;
        connection pumpToOxygenator : BloodConnection
            connect rollerPump.pumpOut to bubbleOxygenator.oxygenatorIn;
        connection oxygenatorToHeatExchanger : BloodConnection
            connect bubbleOxygenator.oxygenatorOut to heatExchanger.exchangerIn;
        connection heatExchangerToFilter : BloodConnection
            connect heatExchanger.exchangerOut to bloodFilter.filterIn;
        connection filterToArterialCannula : BloodConnection
            connect bloodFilter.filterOut to arterialCannula.arterialIn;
        connection cannulaToPatient : BloodConnection
            connect arterialCannula.arterialOut to patientArterialConnection;

        connection def SignalConnection {
            end :>> source : SignalOutPort;
            end :>> target : SignalInPort;
        }

        connection consoleSignal : SignalConnection
            connect consoleInterface to monitoringConsole.sensorInput;

        // ===== System State Machine =====
        state def OperationState {
            entry; then Standby;
            state Standby {
                entry; then Primed;
                state Primed;
            }
            state Running {
                entry; then Circulating;
                state Circulating;
                state Monitoring;
                transition from Circulating to Monitoring;
                transition from Monitoring to Circulating;
            }
            state EmergencyStop;
            transition from Standby to Running when true;
            transition from Running to EmergencyStop when false;
            transition from EmergencyStop to Standby when true;
        }

        exhibit OperationState;

        satisfy CardiopulmonaryBypassRequirement {
            attribute flowRate : VolumeFlowRate = 5000.0;
            attribute oxygenSaturation : OxygenSaturation = 98.0;
            attribute temperature : Temperature = 37.0;
        }
    }

    // ===== System Context =====
    part def CardiopulmonaryBypassSystem {
        part heartLungMachine : HeartLungMachine;
        part patient : Patient;

        connection venousDrainageLine : HeartLungMachine::BloodConnection
            connect patient.venousDrainage to heartLungMachine.patientVenousConnection;
        connection arterialReturnLine : HeartLungMachine::BloodConnection
            connect heartLungMachine.patientArterialConnection to patient.arterialReturn;
    }
}
</antwort>package HeartLungMachine {
    import ScalarValues::*;
    import Collections::*;

    // ===== Value Types =====
    value type VolumeFlowRate > Real { unit 'mL/min'; }
    value type Pressure > Real { unit 'mmHg'; }
    value type Temperature > Real { unit 'degC'; }
    value type Volume > Real { unit 'mL'; }
    value type OxygenSaturation > Real { unit '%'; }
    value type RotationalSpeed > Real { unit 'rpm'; }
    value type Duration > Real { unit 'min'; }
    value type Power > Real { unit 'W'; }

    // ===== Item Types =====
    item def Blood {
        attribute temperature : Temperature;
        attribute oxygenSaturation : OxygenSaturation;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
        attribute volume : Volume;
    }

    item def DeoxygenatedBlood :> Blood {
        constraint { oxygenSaturation < 75.0; }
    }

    item def OxygenatedBlood :> Blood {
        constraint { oxygenSaturation >= 95.0; }
    }

    item def OxygenGas;
    item def CarbonDioxideGas;
    item def DebrisParticle;
    item def AirBubble;

    // ===== Port Definitions =====
    port def BloodInPort {
        in item blood : Blood;
    }
    port def BloodOutPort {
        out item blood : Blood;
    }
    port def GasInPort {
        in item gas : OxygenGas;
    }
    port def GasOutPort {
        out item gas : CarbonDioxideGas;
    }
    port def SignalOutPort {
        out attribute flowRate : VolumeFlowRate;
        out attribute pressure : Pressure;
        out attribute temperature : Temperature;
        out attribute oxygenSaturation : OxygenSaturation;
    }
    port def SignalInPort {
        in attribute flowRate : VolumeFlowRate;
        in attribute pressure : Pressure;
        in attribute temperature : Temperature;
        in attribute oxygenSaturation : OxygenSaturation;
    }

    // ===== Requirements =====
    requirement def CardiopulmonaryBypassRequirement {
        doc "The system shall temporarily take over the complete function of the patient's heart and lungs during open-heart surgery."
        attribute targetFlowRate : VolumeFlowRate = 5000.0;
        attribute targetOxygenSaturation : OxygenSaturation = 98.0;
        attribute targetTemperature : Temperature = 37.0;
        attribute flowRate : VolumeFlowRate;
        attribute oxygenSaturation : OxygenSaturation;
        attribute temperature : Temperature;
        constraint { flowRate >= targetFlowRate; }
        constraint { oxygenSaturation >= 95.0; }
        constraint { temperature >= 32.0 and temperature <= 37.0; }
    }

    requirement def OxygenationRequirement {
        doc "The Bubble Oxygenator shall raise blood oxygen saturation to at least 95% and release carbon dioxide."
        attribute minOxygenSaturation : OxygenSaturation = 95.0;
        attribute oxygenSaturation : OxygenSaturation;
        constraint { oxygenSaturation >= minOxygenSaturation; }
    }

    requirement def TemperatureControlRequirement {
        doc "The Heat Exchanger shall control blood temperature between 18 degC and 37 degC as required by surgery."
        attribute minTemp : Temperature = 18.0;
        attribute maxTemp : Temperature = 37.0;
        attribute temperature : Temperature;
        constraint { temperature >= minTemp and temperature <= maxTemp; }
    }

    requirement def FiltrationRequirement {
        doc "The Blood Filter shall remove debris particles and air bubbles before blood is returned to the patient."
        attribute debrisCount : Integer = 0;
        attribute airBubbleCount : Integer = 0;
        constraint { debrisCount == 0; }
        constraint { airBubbleCount == 0; }
    }

    requirement def MonitoringRequirement {
        doc "The Monitoring Console shall continuously display blood flow rate, pressure, temperature, and oxygen saturation."
        attribute updateInterval : Duration = 0.5;
    }

    // ===== Parts =====
    part def VenousCannula {
        attribute diameter : Real = 12.0;
        port venousIn : BloodInPort;
        port venousOut : BloodOutPort;
        attribute extractedFlow : VolumeFlowRate;
        action def DrainBlood {
            in item deoxyBlood : DeoxygenatedBlood;
            out item drainedBlood : DeoxygenatedBlood;
        }
        perform DrainBlood;
    }

    part def VenousReservoir {
        attribute capacity : Volume = 3000.0;
        attribute currentVolume : Volume;
        port reservoirIn : BloodInPort;
        port reservoirOut : BloodOutPort;
        action def BufferBlood {
            in item incoming : DeoxygenatedBlood;
            in out item stored : DeoxygenatedBlood;
        }
        perform BufferBlood;
        constraint { currentVolume <= capacity; }
    }

    part def RollerPump {
        attribute rotationSpeed : RotationalSpeed = 100.0;
        attribute maxFlowRate : VolumeFlowRate = 6000.0;
        attribute powerConsumption : Power;
        port pumpIn : BloodInPort;
        port pumpOut : BloodOutPort;
        action def PropelBlood {
            in item bloodIn : Blood;
            out item bloodOut : Blood;
            constraint { bloodOut.flowRate <= maxFlowRate; }
        }
        perform PropelBlood;
    }

    part def BubbleOxygenator {
        attribute oxygenFlowRate : VolumeFlowRate = 5000.0;
        attribute heatLoss : Power;
        port oxygenatorIn : BloodInPort;
        port oxygenatorOut : BloodOutPort;
        port gasSupply : GasInPort;
        port gasExhaust : GasOutPort;
        action def OxygenateBlood {
            in item deoxyBlood : DeoxygenatedBlood;
            in item oxygen : OxygenGas;
            out item oxyBlood : OxygenatedBlood;
            out item co2 : CarbonDioxideGas;
            constraint { oxyBlood.oxygenSaturation >= 95.0; }
        }
        perform OxygenateBlood;
        satisfy OxygenationRequirement;
    }

    part def HeatExchangerUnit {
        attribute targetTemperature : Temperature = 37.0;
        attribute heatingPower : Power;
        port exchangerIn : BloodInPort;
        port exchangerOut : BloodOutPort;
        action def RegulateTemperature {
            in item bloodIn : Blood;
            in attribute setPoint : Temperature;
            out item bloodOut : Blood;
            constraint { bloodOut.temperature == setPoint; }
        }
        perform RegulateTemperature;
        satisfy TemperatureControlRequirement;
    }

    part def BloodFilter {
        attribute poreSize : Real = 40.0;
        port filterIn : BloodInPort;
        port filterOut : BloodOutPort;
        action def FilterBlood {
            in item bloodIn : Blood;
            in out item debris : DebrisParticle[*];
            in out item air : AirBubble[*];
            out item bloodOut : Blood;
        }
        perform FilterBlood;
        satisfy FiltrationRequirement;
    }

    part def ArterialCannula {
        attribute diameter : Real = 10.0;
        port arterialIn : BloodInPort;
        port arterialOut : BloodOutPort;
        action def ReturnBlood {
            in item oxyBlood : OxygenatedBlood;
            out item returnedBlood : OxygenatedBlood;
        }
        perform ReturnBlood;
    }

    part def MonitoringConsole {
        attribute displayFlowRate : VolumeFlowRate;
        attribute displayPressure : Pressure;
        attribute displayTemperature : Temperature;
        attribute displayOxygenSaturation : OxygenSaturation;
        port sensorInput : SignalInPort;
        action def DisplayParameters {
            in attribute flowRate : VolumeFlowRate;
            in attribute pressure : Pressure;
            in attribute temperature : Temperature;
            in attribute oxygenSaturation : OxygenSaturation;
        }
        perform DisplayParameters;
        satisfy MonitoringRequirement;
    }

    part def Patient {
        attribute bodyWeight : Real = 70.0;
        port venousDrainage : BloodOutPort;
        port arterialReturn : BloodInPort;
        state def PhysiologicalState {
            entry; then OnBypass;
            state OnBypass;
            state OffBypass;
            transition from OnBypass to OffBypass when true;
        }
        exhibit PhysiologicalState;
    }

    // ===== System =====
    part def HeartLungMachine {
        port patientVenousConnection : BloodInPort;
        port patientArterialConnection : BloodOutPort;
        port consoleInterface : SignalOutPort;

        part venousCannula : VenousCannula;
        part venousReservoir : VenousReservoir;
        part rollerPump : RollerPump;
        part bubbleOxygenator : BubbleOxygenator;
        part heatExchanger : HeatExchangerUnit;
        part bloodFilter : BloodFilter;
        part arterialCannula : ArterialCannula;
        part monitoringConsole : MonitoringConsole;

        connection def BloodConnection {
            end :>> source : BloodOutPort;
            end :>> target : BloodInPort;
            flow bloodFlow : Blood from source.blood to target.blood;
        }

        connection patientToCannula : BloodConnection
            connect patientVenousConnection to venousCannula.venousIn;
        connection cannulaToReservoir : BloodConnection
            connect venousCannula.venousOut to venousReservoir.reservoirIn;
        connection reservoirToPump : BloodConnection
            connect venousReservoir.reservoirOut to rollerPump.pumpIn;
        connection pumpToOxygenator : BloodConnection
            connect rollerPump.pumpOut to bubbleOxygenator.oxygenatorIn;
        connection oxygenatorToHeatExchanger : BloodConnection
            connect bubbleOxygenator.oxygenatorOut to heatExchanger.exchangerIn;
        connection heatExchangerToFilter : BloodConnection
            connect heatExchanger.exchangerOut to bloodFilter.filterIn;
        connection filterToArterialCannula : BloodConnection
            connect bloodFilter.filterOut to arterialCannula.arterialIn;
        connection cannulaToPatient : BloodConnection
            connect arterialCannula.arterialOut to patientArterialConnection;

        connection def SignalConnection {
            end :>> source : SignalOutPort;
            end :>> target : SignalInPort;
        }

        connection consoleSignal : SignalConnection
            connect consoleInterface to monitoringConsole.sensorInput;

        // ===== System State Machine =====
        state def OperationState {
            entry; then Standby;
            state Standby {
                entry; then Primed;
                state Primed;
            }
            state Running {
                entry; then Circulating;
                state Circulating;
                state Monitoring;
                transition from Circulating to Monitoring when true;
                transition from Monitoring to Circulating when true;
            }
            state EmergencyStop;
            transition from Standby to Running when true;
            transition from Running to EmergencyStop when false;
            transition from EmergencyStop to Standby when true;
        }

        exhibit OperationState;

        satisfy CardiopulmonaryBypassRequirement {
            attribute flowRate : VolumeFlowRate = 5000.0;
            attribute oxygenSaturation : OxygenSaturation = 98.0;
            attribute temperature : Temperature = 37.0;
        }
    }

    // ===== System Context =====
    part def CardiopulmonaryBypassSystem {
        part heartLungMachine : HeartLungMachine;
        part patient : Patient;

        connection venousDrainageLine : HeartLungMachine::BloodConnection
            connect patient.venousDrainage to heartLungMachine.patientVenousConnection;
        connection arterialReturnLine : HeartLungMachine::BloodConnection
            connect heartLungMachine.patientArterialConnection to patient.arterialReturn;
    }
}
