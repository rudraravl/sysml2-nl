package SARSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // Value Types
    def FrequencyValue :> Real { unit = "Hz"; }
    def PowerValue :> Real { unit = "W"; }
    def DistanceValue :> Real { unit = "m"; }
    def VelocityValue :> Real { unit = "m/s"; }
    def AngleValue :> Real { unit = "rad"; }
    def TimeValue :> Real { unit = "s"; }
    def DataRateValue :> Real { unit = "bit/s"; }
    def MemoryValue :> Real { unit = "GB"; }
    
    // Items
    item def RadarPulse {
        attribute frequency : FrequencyValue;
        attribute duration : TimeValue;
        attribute power : PowerValue;
    }
    
    item def RadarEcho {
        attribute amplitude : Real;
        attribute phase : AngleValue;
        attribute timeDelay : TimeValue;
    }
    
    item def NavigationData {
        attribute positionX : DistanceValue;
        attribute positionY : DistanceValue;
        attribute positionZ : DistanceValue;
        attribute velocity : VelocityValue;
        attribute pitch : AngleValue;
        attribute roll : AngleValue;
        attribute yaw : AngleValue;
        attribute timestamp : TimeValue;
    }
    
    item def RawSARData {
        attribute echoData : RadarEcho[0..*];
        attribute navData : NavigationData[0..*];
        attribute timestamp : TimeValue;
    }
    
    item def FocusedSARData {
        attribute rangeCompressed : Real[0..*];
        attribute azimuthCompressed : Real[0..*];
        attribute timestamp : TimeValue;
    }
    
    item def SARImage {
        attribute pixels : Real[0..*];
        attribute resolution : DistanceValue;
        attribute geolocationX : DistanceValue;
        attribute geolocationY : DistanceValue;
        attribute calibrationFactor : Real;
    }
    
    // Enumerations
    enum ImagingMode { StripMap, Spotlight, ScanSAR }
    
    // Ports
    port def PulsePort { out pulse : RadarPulse; }
    port def EchoPort { out echo : RadarEcho; }
    port def NavDataPort { out navData : NavigationData; }
    port def RawDataPort { out rawData : RawSARData; }
    port def FocusedDataPort { out focusedData : FocusedSARData; }
    port def ImagePort { out image : SARImage; }
    port def PowerPort { out voltage : Real; }
    port def TimingPort { out clockSignal : TimeValue; }
    
    // Parts
    part def Antenna {
        port rxPort : ~PulsePort;
        port txPort : EchoPort;
    }
    
    part def TransmitReceiveModule {
        port txPort : PulsePort;
        port rxPort : ~EchoPort;
        port echoOutPort : EchoPort;
        port timingPort : ~TimingPort;
        port powerPort : ~PowerPort;
        attribute transmitPower : PowerValue;
    }
    
    part def PlatformNavigationSystem {
        port navPort : NavDataPort;
        port powerPort : ~PowerPort;
        port timingPort : ~TimingPort;
    }
    
    part def DataStorage {
        port navInPort : ~NavDataPort;
        port echoInPort : ~EchoPort;
        port rawOutPort : RawDataPort;
        port powerPort : ~PowerPort;
        port timingPort : ~TimingPort;
        attribute capacity : MemoryValue;
    }
    
    part def SignalProcessor {
        port rawInPort : ~RawDataPort;
        port focusedOutPort : FocusedDataPort;
        port powerPort : ~PowerPort;
        port timingPort : ~TimingPort;
    }
    
    part def ImageFormationProcessor {
        port focusedInPort : ~FocusedDataPort;
        port navInPort : ~NavDataPort;
        port imageOutPort : ImagePort;
        port powerPort : ~PowerPort;
        port timingPort : ~TimingPort;
    }
    
    part def PowerSupply {
        port powerOut : PowerPort;
        attribute maxPower : PowerValue;
    }
    
    part def TimingUnit {
        port timingOut : TimingPort;
        port powerPort : ~PowerPort;
        attribute stability : Real;
    }
    
    // State Machine
    state def SARStateMachine {
        entry; then Idle;
        
        state Idle;
        transition IdleToConfiguring 
            from Idle to Configuring 
            when (true);
            
        state Configuring {
            entry action configureSystem {
                // Set imaging parameters based on mode
            }
        }
        transition ConfiguringToAcquiring 
            from Configuring to Acquiring 
            when (true);
            
        state Acquiring {
            entry action acquireData {
                // Transmit pulses and receive echoes
            }
            do action storeData {
                // Store raw data and nav data
            }
        }
        transition AcquiringToProcessing 
            from Acquiring to Processing 
            when (true);
            
        state Processing {
            entry action focusData {
                // Range and azimuth compression
            }
            do action formImage {
                // Motion compensation and image formation
            }
        }
        transition ProcessingToIdle 
            from Processing to Idle 
            when (true);
    }
    
    // Main System
    part def SARSystem {
        attribute imagingMode : ImagingMode = ImagingMode::StripMap;
        
        part antenna : Antenna;
        part txRxModule : TransmitReceiveModule;
        part navSystem : PlatformNavigationSystem;
        part dataStorage : DataStorage;
        part signalProcessor : SignalProcessor;
        part imageProcessor : ImageFormationProcessor;
        part powerSupply : PowerSupply;
        part timingUnit : TimingUnit;
        
        // Connections
        connection txToAntenna connect txRxModule.txPort to antenna.rxPort;
        connection rxFromAntenna connect antenna.txPort to txRxModule.rxPort;
        
        connection navToStorage connect navSystem.navPort to dataStorage.navInPort;
        connection echoToStorage connect txRxModule.echoOutPort to dataStorage.echoInPort;
        
        connection storageToSignal connect dataStorage.rawOutPort to signalProcessor.rawInPort;
        connection signalToImage connect signalProcessor.focusedOutPort to imageProcessor.focusedInPort;
        connection navToImage connect navSystem.navPort to imageProcessor.navInPort;
        
        // Power distribution
        connection powerToTxRx connect powerSupply.powerOut to txRxModule.powerPort;
        connection powerToNav connect powerSupply.powerOut to navSystem.powerPort;
        connection powerToStorage connect powerSupply.powerOut to dataStorage.powerPort;
        connection powerToSignal connect powerSupply.powerOut to signalProcessor.powerPort;
        connection powerToImage connect powerSupply.powerOut to imageProcessor.powerPort;
        connection powerToTiming connect powerSupply.powerOut to timingUnit.powerPort;
        
        // Timing distribution
        connection timingToTxRx connect timingUnit.timingOut to txRxModule.timingPort;
        connection timingToNav connect timingUnit.timingOut to navSystem.timingPort;
        connection timingToStorage connect timingUnit.timingOut to dataStorage.timingPort;
        connection timingToSignal connect timingUnit.timingOut to signalProcessor.timingPort;
        connection timingToImage connect timingUnit.timingOut to imageProcessor.timingPort;
        
        // Behavior
        state sarOperation : SARStateMachine;
    }
    
    // Requirements
    requirement def SARSystemRequirements {
        subject sarSystem : SARSystem;
        
        requirement OperationalCapability {
            subject sar : SARSystem;
            requirement OperateDayOrNight {
                doc /* The system shall operate effectively day or night. */
            }
            requirement OperateThroughClouds {
                doc /* The system shall operate through clouds or adverse weather. */
            }
        }
        
        requirement HardwareComponents {
            subject sar : SARSystem;
            requirement TransmitReceiveCapability {
                doc /* The system shall send out powerful, precisely-timed radio pulses and listen for echoes. */
            }
            requirement NavigationCapability {
                doc /* The system shall record exact position, speed, and orientation. */
            }
            requirement StorageCapability {
                doc /* The system shall temporarily store raw echo and navigation data. */
            }
            requirement SignalProcessingCapability {
                doc /* The system shall compress data in range and azimuth dimensions. */
            }
            requirement ImageFormationCapability {
                doc /* The system shall correct for flight path deviations and assemble a calibrated 2D image. */
            }
            requirement PowerSupplyCapability {
                doc /* The system shall be powered by a central power supply. */
            }
            requirement TimingSynchronization {
                doc /* The system shall synchronize operations with a highly stable timing unit. */
            }
        }
        
        requirement ImagingModes {
            subject sar : SARSystem;
            requirement StripMapMode {
                doc /* The system shall support StripMap mode for continuous swaths. */
            }
            requirement SpotlightMode {
                doc /* The system shall support Spotlight mode for highest resolution. */
            }
            requirement ScanSARMode {
                doc /* The system shall support ScanSAR mode for wide area coverage. */
            }
        }
        
        requirement OutputRequirement {
            subject sar : SARSystem;
            requirement GeolocatedImageOutput {
                doc /* The system shall output a fully processed and geolocated image. */
            }
        }
    }
}
