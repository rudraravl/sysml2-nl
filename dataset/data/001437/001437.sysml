package GrapheneBasedElectronicSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def LayerCount :> Integer;
    attribute def ConductivityValue :> Real;
    attribute def MobilityValue :> Real;
    attribute def TransmittanceValue :> Real;
    
    attribute def ElectricalConductivity :> Real {
        doc /* Electrical conductivity measured in Siemens per meter */
    }
    
    attribute def CarrierMobility :> Real {
        doc /* Charge carrier mobility measured in cm²/(V·s) */
    }
    
    attribute def OpticalTransmittance :> Real {
        doc /* Optical transmittance as percentage */
    }
    
    item def GrapheneSheet {
        attribute numberOfLayers : LayerCount;
        attribute conductivity : ElectricalConductivity;
        attribute carrierMobility : CarrierMobility;
        attribute opticalTransmittance : OpticalTransmittance;
        attribute surfaceArea : ISQ::AreaValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : ISQ::ElectricPotentialDifferenceValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute frequency : ISQ::FrequencyValue;
    }
    
    item def OpticalSignal {
        attribute intensity : ISQ::PowerValue;
        attribute wavelength : ISQ::LengthValue;
    }
    
    port def ElectricalInputPort {
        in attribute inputSignal : ElectricalSignal;
    }
    
    port def ElectricalOutputPort {
        out attribute outputSignal : ElectricalSignal;
    }
    
    port def OpticalInputPort {
        in attribute lightInput : OpticalSignal;
    }
    
    port def OpticalOutputPort {
        out attribute lightOutput : OpticalSignal;
    }
    
    port def ThermalPort {
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute heatFlux : ISQ::PowerValue;
    }
    
    connection def ElectricalConnection {
        end source : ElectricalOutputPort;
        end target : ElectricalInputPort;
    }
    
    connection def OpticalConnection {
        end source : OpticalOutputPort;
        end target : OpticalInputPort;
    }
    
    connection def ThermalConnection {
        end source : ThermalPort;
        end target : ThermalPort;
    }
    
    part def GrapheneTransistor {
        attribute gateVoltage : ISQ::ElectricPotentialDifferenceValue;
        attribute drainCurrent : ISQ::ElectricCurrentValue;
        attribute transconductance : Real;
        
        port sourcePort : ElectricalInputPort;
        port drainPort : ElectricalOutputPort;
        port gatePort : ElectricalInputPort;
        
        part grapheneChannel : GrapheneSheet {
            attribute :>> numberOfLayers = 1;
            attribute :>> conductivity = 1.0e8;
            attribute :>> carrierMobility = 200000.0;
            attribute :>> surfaceArea = 1.0e-10[SI::m^2];
        }
    }
    
    part def VoltageSource {
        attribute outputVoltage : ISQ::ElectricPotentialDifferenceValue;
        port output : ElectricalOutputPort;
    }
    
    part def CurrentMeter {
        attribute measuredCurrent : ISQ::ElectricCurrentValue;
        port input : ElectricalInputPort;
    }
    
    part def OpticalModulator {
        attribute modulationDepth : Real;
        attribute insertionLoss : Real;
        
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;
        port controlSignal : ElectricalInputPort;
        
        part grapheneLayer : GrapheneSheet {
            attribute :>> numberOfLayers = 2;
            attribute :>> opticalTransmittance = 95.4;
        }
    }
    
    part def HeatSink {
        attribute thermalResistance : Real;
        attribute maxDissipation : ISQ::PowerValue;
        port thermalInterface : ThermalPort;
    }
    
    action def InitializeGrapheneDevice {
        in layerSpec : LayerCount;
        in targetConductivity : ElectricalConductivity;
        out initializedSheet : GrapheneSheet;
    }
    
    action def ApplyGateVoltage {
        in voltage : ISQ::ElectricPotentialDifferenceValue;
        in transistor : GrapheneTransistor;
        out modulatedCurrent : ISQ::ElectricCurrentValue;
    }
    
    action def ModulateOpticalSignal {
        in inputLight : OpticalSignal;
        in controlVoltage : ISQ::ElectricPotentialDifferenceValue;
        in modulator : OpticalModulator;
        out modulatedLight : OpticalSignal;
    }
    
    action def MeasureElectricalResponse {
        in appliedVoltage : ISQ::ElectricPotentialDifferenceValue;
        in device : GrapheneTransistor;
        out responseData : ElectricalSignal;
    }
    
    action def DissipateHeat {
        in generatedHeat : ISQ::PowerValue;
        in heatSink : HeatSink;
        out ambientTemperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    attribute def OperationCommand;
    attribute def ShutdownCommand;
    attribute def CalibrationCommand;
    
    state def GrapheneDeviceStates {
        entry; then initialization;
        
        state initialization {
            entry assign devicePower := 0.0[SI::W];
        }
        
        transition initialization_to_standby
            first initialization
            accept startCommand : OperationCommand
            then standby;
        
        state standby {
            entry assign devicePower := 0.1[SI::W];
        }
        
        transition standby_to_active
            first standby
            if gateVoltage > 0.0[SI::V]
            then active;
        
        state active {
            entry assign devicePower := nominalOperatingPower;
            
            state conducting {
                entry; then measureConductance;
                
                state measureConductance;
                
                transition measureConductance_to_amplifying
                    first measureConductance
                    if drainCurrent > currentThreshold
                    then amplifying;
            }
            
            state amplifying {
                entry; then processSignal;
                
                state processSignal;
                
                transition processSignal_to_modulating
                    first processSignal
                    if opticalInputPresent == true
                    then modulating;
            }
            
            state modulating {
                entry; then modulateLight;
                state modulateLight;
            }
            
            state thermalRegulation {
                entry; then monitorTemperature;
                
                state monitorTemperature;
                
                transition monitorTemperature_to_cooling
                    first monitorTemperature
                    if deviceTemperature > maxOperatingTemperature
                    then cooling;
                
                state cooling {
                    entry assign coolingActive := true;
                }
                
                transition cooling_to_monitorTemperature
                    first cooling
                    if deviceTemperature <= normalOperatingTemperature
                    then monitorTemperature;
            }
        }
        
        transition active_to_standby
            first active
            accept shutdownCommand : ShutdownCommand
            then standby;
        
        transition standby_to_calibration
            first standby
            accept calibrationCommand : CalibrationCommand
            then calibration;
        
        state calibration {
            entry assign devicePower := 0.05[SI::W];
        }
        
        transition calibration_to_standby
            first calibration
            then standby;
        
        state fault {
            entry assign devicePower := 0.0[SI::W];
        }
        
        transition active_to_fault
            first active
            if deviceTemperature > criticalTemperature or drainCurrent > maxCurrent
            then fault;
        
        done;
    }
    
    attribute devicePower : ISQ::PowerValue;
    attribute nominalOperatingPower : ISQ::PowerValue;
    attribute gateVoltage : ISQ::ElectricPotentialDifferenceValue;
    attribute drainCurrent : ISQ::ElectricCurrentValue;
    attribute currentThreshold : ISQ::ElectricCurrentValue;
    attribute opticalInputPresent : Boolean;
    attribute deviceTemperature : ISQ::ThermodynamicTemperatureValue;
    attribute maxOperatingTemperature : ISQ::ThermodynamicTemperatureValue;
    attribute normalOperatingTemperature : ISQ::ThermodynamicTemperatureValue;
    attribute criticalTemperature : ISQ::ThermodynamicTemperatureValue;
    attribute maxCurrent : ISQ::ElectricCurrentValue;
    attribute coolingActive : Boolean;
    
    part def GrapheneElectronicSystem {
        doc /*
            A graphene-based electronic system that leverages the exceptional electrical
            and optical properties of graphene to perform high-speed signal processing
            and optical modulation. The system integrates graphene transistors for
            electrical amplification with graphene-based optical modulators to enable
            electro-optic signal conversion and processing at unprecedented speeds.
            The primary function is to receive electrical input signals, amplify them
            through graphene transistors, and modulate optical carriers for high-bandwidth
            communication while maintaining efficient thermal management.
        */
        
        part transistorStage : GrapheneTransistor {
            attribute :>> gateVoltage = 2.0[SI::V];
            attribute :>> transconductance = 5.0;
        }
        
        part biasSource : VoltageSource {
            attribute :>> outputVoltage = 1.5[SI::V];
        }
        
        part outputMonitor : CurrentMeter {
            attribute :>> measuredCurrent = 0.0[SI::A];
        }
        
        part opticalModulationStage : OpticalModulator {
            attribute :>> modulationDepth = 0.15;
            attribute :>> insertionLoss = 3.0;
        }
        
        part thermalManagement : HeatSink {
            attribute :>> thermalResistance = 10.0;
            attribute :>> maxDissipation = 5.0[SI::W];
        }
        
        connection biasConnection : ElectricalConnection
            connect biasSource.output to transistorStage.gatePort;
        
        connection transistorOutput : ElectricalConnection
            connect transistorStage.drainPort to outputMonitor.input;
        
        connection modulatorControl : ElectricalConnection
            connect transistorStage.drainPort to opticalModulationStage.controlSignal;
        
        connection thermalPath : ThermalConnection
            connect transistorStage.grapheneChannel to thermalManagement.thermalInterface;
        
        perform action systemOperation : OperateGrapheneSystem;
    }
    
    part grapheneElectronicSystem : GrapheneElectronicSystem;
    
    action def OperateGrapheneSystem {
        in inputVoltage : ISQ::ElectricPotentialDifferenceValue;
        in inputOpticalPower : ISQ::PowerValue;
        out amplifiedCurrent : ISQ::ElectricCurrentValue;
        out modulatedOpticalOutput : ISQ::PowerValue;
        
        first start;
        then merge continuousOperation;
        
        action initializeDevice : InitializeGrapheneDevice {
            in layerSpec = 1;
            in targetConductivity = 1.0e8;
            out initializedSheet;
        }
        then continuousOperation;
        
        action applyBias : ApplyGateVoltage {
            in voltage = inputVoltage;
            in transistor;
            out modulatedCurrent;
        }
        then continuousOperation;
        
        action measureResponse : MeasureElectricalResponse {
            in appliedVoltage = inputVoltage;
            in device;
            out responseData;
        }
        then continuousOperation;
        
        action modulateLight : ModulateOpticalSignal {
            in inputLight {
                attribute :>> intensity = inputOpticalPower;
            }
            in controlVoltage = inputVoltage;
            in modulator;
            out modulatedLight;
        }
        then continuousOperation;
        
        action manageThermal : DissipateHeat {
            in generatedHeat = 2.0[SI::W];
            in heatSink;
            out ambientTemperature;
        }
        
        then decide;
            if manageThermal.ambientTemperature < 320.0[SI::K] then continuousOperation;
            if manageThermal.ambientTemperature >= 320.0[SI::K] then emergencyShutdown;
        
        action emergencyShutdown {
            assign amplifiedCurrent := 0.0[SI::A];
            assign modulatedOpticalOutput := 0.0[SI::W];
        }
        
        then done;
    }
    
    requirement def ElectricalPerformanceRequirement {
        attribute minTransconductance : Real;
        attribute maxGateVoltage : ISQ::ElectricPotentialDifferenceValue;
        attribute minCarrierMobility : CarrierMobility;
    }
    
    requirement def OpticalPerformanceRequirement {
        attribute minModulationDepth : Real;
        attribute maxInsertionLoss : Real;
        attribute minTransmittance : OpticalTransmittance;
    }
    
    requirement def ThermalPerformanceRequirement {
        attribute maxOperatingTemp : ISQ::ThermodynamicTemperatureValue;
        attribute minThermalDissipation : ISQ::PowerValue;
    }
    
    requirement def ReliabilityRequirement {
        attribute minOperatingLifetime : ISQ::TimeValue;
        attribute maxFailureRate : Real;
    }
    
    requirement <'REQ-ELEC-001'> electricalPerformance : ElectricalPerformanceRequirement {
        doc /*
            The graphene transistor shall achieve transconductance exceeding 5 S/mm
            with carrier mobility above 15000 cm²/(V·s) at gate voltages below 3V.
        */
        attribute :>> minTransconductance = 5.0;
        attribute :>> maxGateVoltage = 3.0[SI::V];
        attribute :>> minCarrierMobility = 15000.0;
    }
    
    requirement <'REQ-OPT-001'> opticalPerformance : OpticalPerformanceRequirement {
        doc /*
            The graphene optical modulator shall provide modulation depth greater than
            0.1 dB/μm with insertion loss below 5 dB and optical transmittance above 90%.
        */
        attribute :>> minModulationDepth = 0.1;
        attribute :>> maxInsertionLoss = 5.0;
        attribute :>> minTransmittance = 90.0;
    }
    
    requirement <'REQ-THRM-001'> thermalPerformance : ThermalPerformanceRequirement {
        doc /*
            The system shall maintain operating temperature below 350K while dissipating
            at least 5W of thermal power through integrated heat management.
        */
        attribute :>> maxOperatingTemp = 350.0[SI::K];
        attribute :>> minThermalDissipation = 5.0[SI::W];
    }
    
    requirement <'REQ-REL-001'> systemReliability : ReliabilityRequirement {
        doc /*
            The graphene electronic system shall operate continuously for at least
            10000 hours with failure rate below 0.001% per hour.
        */
        attribute :>> minOperatingLifetime = 10000.0[SI::h];
        attribute :>> maxFailureRate = 0.00001;
    }
    
    requirement <'REQ-SYS-MISSION'> primarySystemMission {
        doc /*
            The graphene-based electronic system shall perform high-speed electrical
            signal amplification and electro-optic modulation by exploiting graphene's
            exceptional charge carrier mobility, electrical conductivity, and optical
            properties to enable next-generation high-bandwidth communication and
            signal processing applications with superior performance compared to
            conventional semiconductor technologies.
        */
        
        require electricalPerformance;
        require opticalPerformance;
        require thermalPerformance;
        require systemReliability;
    }
}
