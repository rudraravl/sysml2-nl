package EnergyManagementCircuit {
    import ScalarValues::*;
    import ISQ::*;
    
    value def VoltageValue :> Real {
        doc /* Electrical potential difference in volts (V). */;
    }
    
    value def CurrentValue :> Real {
        doc /* Electric current in amperes (A). */;
    }
    
    value def ResistanceValue :> Real {
        doc /* Electrical resistance in ohms (Ω). */;
    }
    
    value def InductanceValue :> Real {
        doc /* Inductance in henries (H). */;
    }
    
    value def MagneticFluxValue :> Real {
        doc /* Magnetic flux in webers (Wb). */;
    }
    
    value def EnergyValue :> Real {
        doc /* Energy in joules (J). */;
    }
    
    value def PowerValue :> Real {
        doc /* Power in watts (W). */;
    }
    
    value def TimeValue :> Real {
        doc /* Time in seconds (s). */;
    }
    
    value def TurnCount :> Integer {
        doc /* Number of wire turns on the inductor core. */;
    }
    
    item def ElectricalEnergy {
        doc /* Electrical energy flowing through the circuit. */;
    }
    
    item def MagneticFieldEnergy {
        doc /* Energy stored in the inductor magnetic field. */;
    }
    
    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def MeasurementOutputPort {
        attribute measuredCurrent : CurrentValue;
        attribute measurementValid : Boolean;
    }
    
    connection def ElectricalWire {
        end source : ElectricalPort;
        end target : ElectricalPort;
    }
    
    requirement def EnergyStorageRequirement {
        doc /* The system shall store electrical energy in a magnetic field using an inductor. */;
        subject circuit : EnergyManagementCircuit;
        assume { circuit.supplyVoltage == 12.0; }
        require { circuit.inductor.storedEnergy >= 0.0; }
    }
    
    requirement def CurrentSmoothingRequirement {
        doc /* The inductor shall oppose changes in current to smooth the electrical supply. */;
        subject inductor : Inductor;
        require { inductor.inductance > 0.0; }
    }
    
    requirement def CurrentMonitoringRequirement {
        doc /* A current sensor shall actively monitor the current flowing through the circuit. */;
        subject sensor : CurrentSensor;
        require { sensor.isMonitoring == true; }
    }
    
    requirement def SaturationProtectionRequirement {
        doc /* The system shall detect and handle the saturated state of the inductor core. */;
        subject inductor : Inductor;
        require { inductor.saturationLimit > 0.0; }
    }
    
    part def FerriteCore {
        attribute relativePermeability : Real = 2000.0;
        attribute crossSectionalArea : Real = 1.0e-4;
        attribute magneticPathLength : Real = 0.05;
        attribute saturationFluxDensity : MagneticFluxValue = 0.3;
        attribute isSaturated : Boolean = false;
        
        action def checkSaturation {
            doc /* Check if the core has reached magnetic saturation. */;
        }
    }
    
    part def WireWinding {
        attribute turnCount : TurnCount = 100;
        attribute wireDiameter : Real = 0.5e-3;
        attribute wireResistance : ResistanceValue = 0.1;
        attribute windingLength : Real = 5.0;
    }
    
    part def PowerSupply {
        port out positiveTerminal : ElectricalPort;
        port out negativeTerminal : ElectricalPort;
        
        attribute nominalVoltage : VoltageValue = 12.0;
        attribute isPoweredOn : Boolean = true;
        attribute maxOutputCurrent : CurrentValue = 5.0;
        
        action def supplyPower {
            doc /* Supply 12V DC power to the circuit. */;
        }
        
        action def togglePower {
            doc /* Toggle power on or off. */;
        }
    }
    
    part def Inductor {
        port in inputPort : ElectricalPort;
        port out outputPort : ElectricalPort;
        
        part core : FerriteCore;
        part winding : WireWinding;
        
        attribute inductance : InductanceValue = 1.0e-3;
        attribute storedEnergy : EnergyValue = 0.0;
        attribute magneticFlux : MagneticFluxValue = 0.0;
        attribute saturationLimit : MagneticFluxValue = 0.3;
        attribute currentFlow : CurrentValue = 0.0;
        attribute targetCurrent : CurrentValue = 1.2;
        attribute isSaturated : Boolean = false;
        
        constraint energyFormula {
            doc /* Stored energy E = 0.5 * L * I^2. */;
            storedEnergy == 0.5 * inductance * currentFlow * currentFlow;
        }
        
        constraint fluxLimit {
            doc /* Magnetic flux must not exceed saturation limit in normal operation. */;
            magneticFlux <= saturationLimit;
        }
        
        state machine InductorStates {
            entry { doc /* Initialize inductor state machine. */; }
            
            state charging {
                entry { doc /* Begin building magnetic field; resist initial current surge. */; }
                do { doc /* Oppose current increase through back EMF; gradually build magnetic flux. */; }
                exit { doc /* Exit charging state. */; }
                transition to steady when currentFlow >= targetCurrent;
                transition to saturated when magneticFlux >= saturationLimit;
            }
            
            state steady {
                entry { doc /* Current stabilized; enter steady-state operation. */; }
                do { doc /* Maintain constant magnetic field; minimal opposition to current. */; }
                exit { doc /* Exit steady state. */; }
                transition to discharging when inputPort.voltage < 1.0;
                transition to saturated when magneticFlux >= saturationLimit;
            }
            
            state discharging {
                entry { doc /* Power removed or fluctuating; release stored magnetic energy. */; }
                do { doc /* Discharge stored energy through load to maintain current flow, smoothing supply. */; }
                exit { doc /* Exit discharging state. */; }
                transition to charging when inputPort.voltage >= 11.0;
                transition to steady when currentFlow <= 0.0;
            }
            
            state saturated {
                entry { doc /* Core has reached saturation; cannot store more magnetic energy. */; }
                do { doc /* Inductor behaves as simple conductor; no additional energy storage possible. */; }
                exit { doc /* Exit saturation state. */; }
                transition to discharging when inputPort.voltage < 1.0;
            }
            
            transition initial to charging;
        }
        
        action def charge {
            doc /* Build magnetic field by opposing current increase. */;
        }
        
        action def discharge {
            doc /* Release stored magnetic energy to maintain current flow. */;
        }
        
        action def maintainField {
            doc /* Maintain stable magnetic field in steady state. */;
        }
        
        action def handleSaturation {
            doc /* Handle saturation condition by reporting and limiting energy storage. */;
        }
    }
    
    part def LoadResistor {
        port in inputPort : ElectricalPort;
        port out outputPort : ElectricalPort;
        
        attribute resistance : ResistanceValue = 10.0;
        attribute powerDissipation : PowerValue = 0.0;
        attribute isOverloaded : Boolean = false;
        
        constraint ohmsLaw {
            doc /* Power dissipated P = V^2 / R. */;
            powerDissipation == (inputPort.voltage * inputPort.voltage) / resistance;
        }
        
        action def dissipatePower {
            doc /* Convert electrical energy to heat as current flows through resistor. */;
        }
    }
    
    part def CurrentSensor {
        port in inputPort : ElectricalPort;
        port out outputPort : ElectricalPort;
        port out measurementPort : MeasurementOutputPort;
        
        attribute measuredCurrent : CurrentValue = 0.0;
        attribute isMonitoring : Boolean = true;
        attribute samplingRate : Real = 1000.0;
        attribute accuracy : Real = 0.01;
        
        action def monitorCurrent {
            doc /* Continuously sample and report current flowing through the circuit. */;
        }
        
        action def reportMeasurement {
            doc /* Report the measured current value via the measurement port. */;
        }
    }
    
    part def EnergyManagementCircuit {
        attribute supplyVoltage : VoltageValue = 12.0;
        attribute circuitCurrent : CurrentValue = 0.0;
        attribute systemActive : Boolean = true;
        
        part powerSupply : PowerSupply;
        part inductor : Inductor;
        part load : LoadResistor;
        part sensor : CurrentSensor;
        
        connect powerSupply.positiveTerminal to sensor.inputPort;
        connect sensor.outputPort to inductor.inputPort;
        connect inductor.outputPort to load.inputPort;
        connect load.outputPort to powerSupply.negativeTerminal;
        
        requirement energyStorageReq : EnergyStorageRequirement;
        requirement currentSmoothingReq : CurrentSmoothingRequirement;
        requirement currentMonitoringReq : CurrentMonitoringRequirement;
        requirement saturationProtectionReq : SaturationProtectionRequirement;
        
        satisfy energyStorageReq by inductor;
        satisfy currentSmoothingReq by inductor;
        satisfy currentMonitoringReq by sensor;
        satisfy saturationProtectionReq by inductor;
    }
}
