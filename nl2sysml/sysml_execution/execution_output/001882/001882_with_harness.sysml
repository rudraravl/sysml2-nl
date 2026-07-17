package VacuumTubeAmplifierSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def ResistanceValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;
    attribute def PowerValue :> Real;
    attribute def FrequencyValue :> Real;
    
    enum def TubeOperatingState {
        off;
        warmingUp;
        ready;
        amplifying;
        overload;
        failed;
    }
    
    item def AudioSignal {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
        attribute phase : Real;
    }
    
    item def Electron;
    
    port def SignalPort {
        in item inputSignal : AudioSignal;
        out item outputSignal : AudioSignal;
    }
    
    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    part def Cathode {
        attribute temperature : TemperatureValue;
        attribute emissionCurrent : CurrentValue;
        attribute heaterPower : PowerValue;
        port heaterConnection : PowerPort;
        
        action def HeatCathode {
            in heaterVoltage : VoltageValue;
            out cathodeTemp : TemperatureValue;
        }
        
        action def EmitElectrons {
            in temperature : TemperatureValue;
            out electrons : Electron[*];
            out emissionRate : CurrentValue;
        }
    }
    
    part def Anode {
        attribute plateVoltage : VoltageValue;
        attribute plateCurrent : CurrentValue;
        attribute dissipatedPower : PowerValue;
        port plateConnection : PowerPort;
        
        action def CollectElectrons {
            in electrons : Electron[*];
            in plateVoltage : VoltageValue;
            out plateCurrent : CurrentValue;
        }
    }
    
    part def ControlGrid {
        attribute biasVoltage : VoltageValue;
        attribute gridResistance : ResistanceValue;
        attribute transconductance : Real;
        port gridInput : SignalPort;
        
        action def ModulateElectronFlow {
            in gridSignal : AudioSignal;
            in electronStream : Electron[*];
            out modulatedStream : Electron[*];
        }
    }
    
    part def VacuumEnvelope {
        attribute internalPressure : PressureValue;
        attribute glassIntegrity : Boolean;
        
        assert constraint maintainVacuum {
            internalPressure <= 1.0e-6
        }
    }
    
    part def HeaterElement {
        attribute heaterVoltage : VoltageValue;
        attribute heaterCurrent : CurrentValue;
        attribute heaterResistance : ResistanceValue;
        port powerInput : PowerPort;
        
        assert constraint heaterPowerRelation {
            heaterVoltage == heaterCurrent * heaterResistance
        }
    }
    
    part def TriodeVacuumTube {
        attribute amplificationFactor : Real;
        attribute currentState : TubeOperatingState;
        attribute plateVoltage : VoltageValue;
        attribute plateCurrent : CurrentValue;
        attribute gridBias : VoltageValue;
        
        port signalInput : SignalPort;
        port signalOutput : SignalPort;
        port plateSupply : PowerPort;
        port heaterSupply : PowerPort;
        port cathodeGround : PowerPort;
        
        part cathode : Cathode;
        
        part anode : Anode;
        
        part grid : ControlGrid;
        
        part heater : HeaterElement {
            attribute :>> heaterVoltage = 6.3;
            attribute :>> heaterCurrent = 0.3;
        }
        
        part envelope : VacuumEnvelope {
            attribute :>> internalPressure = 1.0e-7;
            attribute :>> glassIntegrity = true;
        }
        
        assert constraint amplificationRelation {
            amplificationFactor == anode.plateVoltage / grid.biasVoltage
        }
        
        state tubeLifecycle {
            entry; then off;
            
            state off;
            
            transition powerApplied
                first off
                accept PowerOn
                then warmingUp;
            
            state warmingUp {
                do action warmup : cathode.HeatCathode;
            }
            
            transition warmupComplete
                first warmingUp
                if cathode.temperature >= 1073.15
                then ready;
            
            state ready;
            
            transition signalDetected
                first ready
                if signalInput.inputSignal.voltage > 0.001
                then amplifying;
            
            state amplifying {
                do action amplify {
                    first start;
                    then action modulate : grid.ModulateElectronFlow;
                    then action collect : anode.CollectElectrons;
                    then done;
                }
            }
            
            transition signalLost
                first amplifying
                if signalInput.inputSignal.voltage <= 0.001
                then ready;
            
            transition overloadDetected
                first amplifying
                if anode.plateCurrent >= 0.1
                then overload;
            
            state overload;
            
            transition overloadCleared
                first overload
                if anode.plateCurrent < 0.08
                then ready;
            
            transition envelopeFailure
                if envelope.glassIntegrity == false
                then failed;
            
            state failed;
        }
    }
    
    part def HighVoltagePowerSupply {
        attribute outputVoltage : VoltageValue;
        attribute outputCurrent : CurrentValue;
        attribute maxPower : PowerValue;
        port hvOutput : PowerPort;
        port acInput : PowerPort;
        
        assert constraint powerLimit {
            outputVoltage * outputCurrent <= maxPower
        }
    }
    
    part def HeaterPowerSupply {
        attribute outputVoltage : VoltageValue;
        attribute outputCurrent : CurrentValue;
        port heaterOutput : PowerPort;
        port acInput : PowerPort;
    }
    
    part def InputTransformer {
        attribute primaryImpedance : ResistanceValue;
        attribute secondaryImpedance : ResistanceValue;
        attribute turnsRatio : Real;
        port primaryInput : SignalPort;
        port secondaryOutput : SignalPort;
    }
    
    part def OutputTransformer {
        attribute primaryImpedance : ResistanceValue;
        attribute secondaryImpedance : ResistanceValue;
        attribute turnsRatio : Real;
        port primaryInput : SignalPort;
        port secondaryOutput : SignalPort;
    }
    
    part def LoadResistor {
        attribute resistance : ResistanceValue;
        attribute powerRating : PowerValue;
        port connection : SignalPort;
    }
    
    part def SignalSource {
        attribute signalAmplitude : VoltageValue;
        attribute signalFrequency : FrequencyValue;
        port output : SignalPort;
        
        action def GenerateSignal {
            out signal : AudioSignal;
        }
    }
    
    action def AmplifyAudioSignal {
        in inputSignal : AudioSignal;
        in gain : Real;
        out outputSignal : AudioSignal;
    }
    
    action def OperateAmplifier {
        first start;
        then merge powerCycle;
        then action applyHeaterPower;
        then action waitForWarmup;
        then decide;
            if cathodeReady then applyHighVoltage;
            if not cathodeReady then waitForWarmup;
        action applyHighVoltage;
        then action monitorInput;
        then decide;
            if signalPresent then amplifySignal;
            if not signalPresent then monitorInput;
        action amplifySignal : AmplifyAudioSignal;
        then decide;
            if continueOperation then powerCycle;
            if shutdownRequested then shutdown;
        action shutdown;
        then done;
        
        attribute cathodeReady : Boolean;
        attribute signalPresent : Boolean;
        attribute continueOperation : Boolean;
        attribute shutdownRequested : Boolean;
    }
    
    part amplifierSystem {
        attribute systemGain : Real = 20.0;
        attribute operatingPlateVoltage : VoltageValue = 250.0;
        attribute heaterVoltage : VoltageValue = 6.3;
        
        part tube : TriodeVacuumTube {
            attribute :>> amplificationFactor = systemGain;
            attribute :>> plateVoltage = operatingPlateVoltage;
            attribute :>> gridBias = -2.0;
        }
        
        part hvSupply : HighVoltagePowerSupply {
            attribute :>> outputVoltage = 250.0;
            attribute :>> outputCurrent = 0.05;
            attribute :>> maxPower = 15.0;
        }
        
        part heaterSupply : HeaterPowerSupply {
            attribute :>> outputVoltage = 6.3;
            attribute :>> outputCurrent = 0.3;
        }
        
        part inputTransformer : InputTransformer {
            attribute :>> primaryImpedance = 600.0;
            attribute :>> secondaryImpedance = 100000.0;
            attribute :>> turnsRatio = 12.9;
        }
        
        part outputTransformer : OutputTransformer {
            attribute :>> primaryImpedance = 5000.0;
            attribute :>> secondaryImpedance = 8.0;
            attribute :>> turnsRatio = 25.0;
        }
        
        part signalSource : SignalSource {
            attribute :>> signalAmplitude = 0.5;
            attribute :>> signalFrequency = 1000.0;
        }
        
        part load : LoadResistor {
            attribute :>> resistance = 8.0;
            attribute :>> powerRating = 10.0;
        }
        
        connection c1 connect signalSource.output to inputTransformer.primaryInput;
        connection c2 connect inputTransformer.secondaryOutput to tube.signalInput;
        connection c3 connect tube.signalOutput to outputTransformer.primaryInput;
        connection c4 connect outputTransformer.secondaryOutput to load.connection;
        connection c5 connect hvSupply.hvOutput to tube.plateSupply;
        connection c6 connect heaterSupply.heaterOutput to tube.heaterSupply;
        
        perform action operate : OperateAmplifier;
    }
    
    requirement <'REQ-VT-001'> primaryFunctionRequirement {
        doc /* The vacuum tube amplifier system shall amplify electrical audio signals 
             * by controlling electron flow from a heated cathode to an anode through 
             * a control grid, providing voltage gain for audio frequency applications.
             */
        subject system : amplifierSystem;
        
        assume constraint inputSignalPresent {
            system.signalSource.signalAmplitude > 0.0
        }
        
        require constraint systemGainAchieved {
            system.systemGain >= 15.0 and system.systemGain <= 25.0
        }
    }
    
    requirement <'REQ-VT-002'> voltageGainRequirement {
        doc /* The amplifier shall provide a minimum voltage gain of 20 dB 
             * across the audio frequency range of 20 Hz to 20 kHz.
             */
        subject tube : TriodeVacuumTube;
        
        require constraint gainSpecification {
            tube.amplificationFactor >= 10.0
        }
    }
    
    requirement <'REQ-VT-003'> operatingVoltageRequirement {
        doc /* The vacuum tube shall operate at a plate voltage between 
             * 200V and 300V for optimal performance and tube longevity.
             */
        subject tube : TriodeVacuumTube;
        
        require constraint plateVoltageRange {
            tube.plateVoltage >= 200.0 and tube.plateVoltage <= 300.0
        }
    }
    
    requirement <'REQ-VT-004'> vacuumIntegrityRequirement {
        doc /* The vacuum envelope shall maintain internal pressure below 
             * 1.0e-6 Pa to ensure proper electron flow and prevent 
             * ionization of residual gas molecules.
             */
        subject envelope : VacuumEnvelope;
        
        require constraint pressureLimit {
            envelope.internalPressure <= 1.0e-6
        }
    }
    
    requirement <'REQ-VT-005'> cathodeTemperatureRequirement {
        doc /* The cathode shall reach and maintain a temperature of at least 
             * 800 degrees Celsius (1073.15 K) for adequate thermionic emission.
             */
        subject cathode : Cathode;
        
        require constraint operatingTemperature {
            cathode.temperature >= 1073.15
        }
    }
    
    requirement <'REQ-VT-006'> powerConsumptionRequirement {
        doc /* The total power consumption of the amplifier system shall not 
             * exceed 20 watts during normal operation.
             */
        subject system : amplifierSystem;
        
        require constraint powerLimit {
            system.hvSupply.maxPower + (system.heaterSupply.outputVoltage * system.heaterSupply.outputCurrent) <= 20.0
        }
    }
    
    requirement <'REQ-VT-007'> warmupTimeRequirement {
        doc /* The amplifier shall reach operational readiness within 60 seconds 
             * after power is applied to allow cathode heating.
             */
        subject tube : TriodeVacuumTube;
    }
    
    satisfy primaryFunctionRequirement by amplifierSystem;
    satisfy voltageGainRequirement by amplifierSystem.tube;
    satisfy operatingVoltageRequirement by amplifierSystem.tube;
    satisfy vacuumIntegrityRequirement by amplifierSystem.tube.envelope;
    satisfy cathodeTemperatureRequirement by amplifierSystem.tube.cathode;
    satisfy powerConsumptionRequirement by amplifierSystem;
    satisfy warmupTimeRequirement by amplifierSystem.tube;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import VacuumTubeAmplifierSystem::*;

    action orchestrator {
        attribute testHeaterVoltage : VoltageValue = 0.0;
        action actionProbe : HeatCathode {
            in heaterVoltage = testHeaterVoltage;
        }
        first actionProbe;
    }
}
