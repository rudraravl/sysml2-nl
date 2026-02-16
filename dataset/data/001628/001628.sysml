package 'Wire Electrical Transmission System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    item def ElectricalSignal {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute power : ISQ::PowerValue;
    }
    
    port def ElectricalTerminal {
        in item signalIn : ElectricalSignal;
        out item signalOut : ElectricalSignal;
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def ConductorMaterial {
        attribute resistivity : ISQ::ResistivityValue;
        attribute conductivity : ISQ::ElectricalConductivityValue;
        attribute temperatureCoefficient : Real;
        attribute density : ISQ::MassPerVolumeValue;
    }
    
    part def InsulationLayer {
        attribute dielectricStrength : ISQ::ElectricFieldStrengthValue;
        attribute thickness : ISQ::LengthValue;
        attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute thermalConductivity : ISQ::ThermalConductivityValue;
    }
    
    part def Wire {
        doc /* A wire is a flexible metallic conductor that transmits electrical energy 
               from a source to a load through electron flow in its conductive core. */
        
        attribute wireLength : ISQ::LengthValue;
        attribute crossSectionalArea : ISQ::AreaValue;
        attribute totalResistance : ISQ::ResistanceValue;
        attribute maxCurrentRating : ISQ::ElectricCurrentValue;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute ambientTemperature : ISQ::ThermodynamicTemperatureValue;
        
        part conductor : ConductorMaterial {
            attribute resistivity = 1.68e-8 [SI::Ω];
            attribute conductivity = 5.96e7 [SI::S];
            attribute temperatureCoefficient = 0.00393;
        }
        
        part insulation : InsulationLayer {
            attribute thickness = 0.8e-3 [SI::m];
            attribute maxTemperature = 363.15 [SI::K];
            attribute dielectricStrength = 20.0e6 [SI::'V/m'];
        }
        
        port inputTerminal : ElectricalTerminal;
        port outputTerminal : ElectricalTerminal;
        
        constraint resistanceCalculation {
            doc /* Total resistance equals resistivity times length divided by cross-sectional area. */
            totalResistance == (conductor.resistivity * wireLength) / crossSectionalArea
        }
        
        constraint voltageDrop {
            doc /* Voltage drop across wire follows Ohm's law. */
            inputTerminal.voltage - outputTerminal.voltage == 
                inputTerminal.current * totalResistance
        }
        
        constraint currentContinuity {
            doc /* Current entering wire equals current leaving wire. */
            inputTerminal.current == outputTerminal.current
        }
        
        constraint temperatureLimit {
            doc /* Operating temperature must not exceed insulation maximum. */
            operatingTemperature <= insulation.maxTemperature
        }
    }
    
    action def ConductElectricalCurrent {
        in inputVoltage : ISQ::VoltageValue;
        in inputCurrent : ISQ::ElectricCurrentValue;
        in resistance : ISQ::ResistanceValue;
        out outputVoltage : ISQ::VoltageValue;
        out outputCurrent : ISQ::ElectricCurrentValue;
        out powerDissipated : ISQ::PowerValue;
        out voltageDrop : ISQ::VoltageValue;
    }
    
    action def MonitorWireTemperature {
        in currentFlow : ISQ::ElectricCurrentValue;
        in resistance : ISQ::ResistanceValue;
        in ambientTemp : ISQ::ThermodynamicTemperatureValue;
        in thermalResistance : Real;
        out wireTemp : ISQ::ThermodynamicTemperatureValue;
    }
    
    action def DetectOverload {
        in actualCurrent : ISQ::ElectricCurrentValue;
        in ratedCurrent : ISQ::ElectricCurrentValue;
        out overloadDetected : Boolean;
    }
    
    state def WireOperationalStates {
        entry; then idle;
        
        state idle {
            doc /* Wire is not conducting current, at ambient temperature. */
        }
        
        transition first accept PowerApplied then conducting;
        
        state conducting {
            doc /* Wire is actively transmitting electrical current. */
            
            do action conductCurrent : ConductElectricalCurrent;
            do action monitorTemp : MonitorWireTemperature;
            do action checkOverload : DetectOverload;
        }
        
        transition accept when checkOverload.overloadDetected then overload;
        
        state overload {
            doc /* Wire current exceeds safe rating, risk of damage. */
            entry send OverloadWarning;
        }
        
        transition accept PowerRemoved then cooling;
        
        state cooling {
            doc /* Wire is cooling down to ambient temperature. */
        }
        
        transition accept when monitorTemp.wireTemp <= ambientTemperature + 5.0 then idle;
    }
    
    action def TransmitElectricalPower {
        doc /* Primary function: transmit electrical power from source to load 
               by conducting current through the wire's metallic conductor while 
               maintaining voltage within acceptable drop limits and temperature 
               within safe operating range. */
        
        in sourceVoltage : ISQ::VoltageValue;
        in sourceCurrent : ISQ::ElectricCurrentValue;
        in wireResistance : ISQ::ResistanceValue;
        in maxSafeTemp : ISQ::ThermodynamicTemperatureValue;
        out loadVoltage : ISQ::VoltageValue;
        out loadCurrent : ISQ::ElectricCurrentValue;
        out transmissionEfficiency : Real;
        
        first start;
        
        then action initiateConduction {
            send PowerApplied;
        }
        
        then merge continuousOperation;
        
        then action conduct : ConductElectricalCurrent {
            in inputVoltage = sourceVoltage;
            in inputCurrent = sourceCurrent;
            in resistance = wireResistance;
            out outputVoltage;
            out outputCurrent;
            out powerDissipated;
            out voltageDrop;
        }
        
        then action monitor : MonitorWireTemperature {
            in currentFlow = conduct.outputCurrent;
            in resistance = wireResistance;
            out wireTemp;
        }
        
        then action evaluateConditions : DetectOverload {
            in actualCurrent = conduct.outputCurrent;
            out overloadDetected;
        }
        
        then decide;
            if monitor.wireTemp < maxSafeTemp and not evaluateConditions.overloadDetected
                then continuousOperation;
            if monitor.wireTemp >= maxSafeTemp or evaluateConditions.overloadDetected
                then shutdownTransmission;
        
        action shutdownTransmission {
            send PowerRemoved;
        }
        
        then done;
    }
    
    part def PowerSource {
        attribute outputVoltage : ISQ::VoltageValue;
        attribute outputCurrent : ISQ::ElectricCurrentValue;
        port output : ElectricalTerminal;
    }
    
    part def ElectricalLoad {
        attribute requiredVoltage : ISQ::VoltageValue;
        attribute requiredCurrent : ISQ::ElectricCurrentValue;
        attribute loadResistance : ISQ::ResistanceValue;
        port input : ElectricalTerminal;
    }
    
    requirement def WireTransmissionRequirements {
        doc /* Wire shall transmit electrical power efficiently and safely. */
        
        require constraint maxVoltageDrop {
            doc /* Voltage drop shall not exceed 3% of source voltage. */
        }
        
        require constraint currentCapacity {
            doc /* Wire shall carry rated current without exceeding temperature limits. */
        }
        
        require constraint powerEfficiency {
            doc /* Transmission efficiency shall be at least 95%. */
        }
    }
    
    requirement <'WR-001'> safeEfficientTransmission : WireTransmissionRequirements {
        doc /* The wire system shall transmit electrical power from source to load 
               safely and efficiently under all normal operating conditions. */
        
        subject transmissionWire : Wire;
        
        assume constraint validSourceParameters {
            doc /* Source voltage and current are within wire ratings. */
        }
        
        require constraint operatingTemperatureLimit {
            doc /* Wire temperature shall remain below insulation maximum. */
            transmissionWire.operatingTemperature < transmissionWire.insulation.maxTemperature
        }
        
        require constraint voltageDropLimit {
            doc /* Voltage drop shall not exceed 3% of input voltage. */
        }
        
        require constraint continuousCurrentFlow {
            doc /* Current continuity shall be maintained throughout transmission. */
            transmissionWire.inputTerminal.current == transmissionWire.outputTerminal.current
        }
    }
    
    part electricalTransmissionSystem {
        doc /* Complete system demonstrating wire's primary function of transmitting 
               electrical power from a source to a load. */
        
        part source : PowerSource {
            attribute outputVoltage = 120.0 [SI::V];
            attribute outputCurrent = 10.0 [SI::A];
        }
        
        part transmissionWire : Wire {
            attribute wireLength = 15.0 [SI::m];
            attribute crossSectionalArea = 3.31e-6 [SI::m2];
            attribute maxCurrentRating = 15.0 [SI::A];
            attribute ambientTemperature = 298.15 [SI::K];
        }
        
        part load : ElectricalLoad {
            attribute requiredVoltage = 115.0 [SI::V];
            attribute requiredCurrent = 10.0 [SI::A];
            attribute loadResistance = 11.5 [SI::Ω];
        }
        
        connect source.output to transmissionWire.inputTerminal;
        connect transmissionWire.outputTerminal to load.input;
        
        perform action operateTransmission : TransmitElectricalPower {
            in sourceVoltage = source.outputVoltage;
            in sourceCurrent = source.outputCurrent;
            in wireResistance = transmissionWire.totalResistance;
            in maxSafeTemp = transmissionWire.insulation.maxTemperature;
            out loadVoltage;
            out loadCurrent;
            out transmissionEfficiency;
        }
        
        exhibit state wireOperation : WireOperationalStates;
        
        satisfy safeEfficientTransmission;
    }
}
