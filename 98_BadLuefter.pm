package main;
use strict;
use warnings;

=pod
define BadLuefter <hum_device> <hum_reading> <switch_device>

i.e.

define badluefter BadLuefter HM_633ADB_Climate humidity schalterbadfeuchte2

attribute
interval    300     # 5*60  Sekunden
on_time     1200

=cut

#my %gets = (  # NameOFCommand =>  StyleMod for Fhemweb, SubToCall if get is executed, String to send to uC, sub called with response, regex to verify response,
my %BadLuefter_gets = (
    HumidityDevice => "HumidityDevice:noArg",
    HumidityReading => "HumidityReading:noArg",
    SwitchDevice => "SwitchDevice:noArg",
    Interval => "Interval:noArg",
    ValueList => "ValueList:noArg" 
);

my @ValueList = (); #global #empty list of values

#should be used instead of getInterval()
my $globalInterval=60;

sub doLog($){
    my $msg=shift;
    Log3 "BadLuefter", 4, $msg;
}

sub getTrend{
    my @aref=@{$_[0]};
    #-- output and average
    my $average = 0;
    my $max = 0;
    my $min = 100;
    my $direction=2;
    #is the value falling or rising or equal?
    #get trend
    my $hTrend=0;
    my $num=scalar @aref; #number of entries
    if($num>2){ #at least 3 values...
      for(my $i=0;$i<$num-1;$i++){
         #if ( (@aref[$i+1] - @aref[$i]) > 0 ){
         if ( ($aref[$i+1] - $aref[$i]) > 0 ){
            $hTrend+=1;
         } 
         #if ( (@aref[$i+1] - @aref[$i]) < 0 ){
         if ( ($aref[$i+1] - $aref[$i]) < 0 ){
            $hTrend-=1;
         } 
      }
      $direction = 1
         if ( $hTrend > 0 );
      $direction = -1
         if ( $hTrend < 0 );
      $direction = 0
         if ( $hTrend == 0 );
    }
    return $direction;
}

# add new value and return trend
sub addToList($){
    my $v=shift;
    my $cnt=scalar(@ValueList);
    my $trend=0;
    if($cnt > 8){
        my $oldest=shift(@ValueList); #remove oldest value if cnt>8
        push(@ValueList, $v); # put newest on top of list
        $trend=getTrend(\@ValueList);
    }else{
        push(@ValueList, $v); # put newest on top of list
    }
    my $list = join(", ", @ValueList);
    Log3 "BadLuefter", 4, ": addToList $v. List=$list";
    
    return $trend; # also returns 0 if cnt <9
}

#get current interval either by internal or via attribute
sub getInterval($){
    my $hash = shift;
    #try attr first
    my $name=$hash->{NAME};
    my $intVal=$attr{$name}{Interval};
    Log3 $name, 4, "getInterval: Interval ist $intVal";
    if(defined ($intVal)){
        return $intVal;
    }else{
##        my $intVal = $hash->{Interval};
##        #get internal interval
##        if (! $intVal ) {
##            $hash->{Interval}=60;
##            $intVal=$hash->{Interval};
##        }
        return 60;
    }
    return 60; #default
}

sub setInterval($$){
    my ($hash, $value) = @_;
    my $name=$hash->{NAME};
    $attr{$name}{Interval}=$value;
    Log3 $name, 4, "setInterval: Interval ist $value";
    $globalInterval=$value;
    #update internal Interval
##    $hash->{Interval}=$value;
}

sub BadLuefter_Initialize {
    my ($hash) = @_;

    $hash->{DefFn}      = \&BadLuefter_Define;
    $hash->{UndefFn}    = \&BadLuefter_Undef;
    $hash->{SetFn}      = \&BadLuefter_Set;
    $hash->{GetFn}      = \&BadLuefter_Get;
    $hash->{AttrFn}     = \&BadLuefter_Attr;
    $hash->{ReadFn}     = \&BadLuefter_Read;
    $hash->{NotifyFn}     = \&BadLuefter_Notify;
    $hash->{GetUpdateFn}     = \&BadLuefter_GetUpdate;
    
    $hash->{AttrList} = "humidity_device Interval on_time verbose " . $readingFnAttributes;
        
    my $inter = 60; # 60 sekunden
##    $hash->{Interval} = $inter; # für die instanz speichern
    $hash->{ValueList}=join(", ", @ValueList);
    $globalInterval=60;
}

# we need an input evice to read the humidity from or a notify
# define badluefter BadLuefter HM_633ADB_Climate humidity schalterbadfeuchte2
sub BadLuefter_Define {
    my ($hash, $def) = @_;
    my @param = split('[ \t]+', $def);
    
    if(int(@param) < 5) {
        return "too few parameters: define <name> BadLuefter <Humidity_Device> <Humidity_Name> <Switch_Device>";
    }
    my $name=$defs{$hash}->{NAME};
#    Log3 $name, 4, "attr HumidityDevice set to $param[2]";
    #$attr{$name}->{HumidityDevice} = $param[2];
#    fhem ("attr $name HumidityDevice $param[2]");
    
    #internals
    $hash->{HumidityDevice}  = $param[2];
    $hash->{HumidityReading}  = $param[3];
    $hash->{SwitchDevice} = $param[4];

##    if (! $hash->{Interval} ) {
##        $hash->{Interval}=60;
##    }
    setInterval($hash, 60);  
    return ;
}

sub BadLuefter_GetUpdate($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3 $name, 4, "BadLuefter: GetUpdate called ...";
	
    my $hashHumDev = $hash->{HumidityDevice};
    my $humReading = $hash->{HumidityReading};
    my $switchDev = $hash->{SwitchDevice};
    #read humidity
    my $hashHumDevice = $defs{$hashHumDev};
    my $hashSwitchDevice = $defs{$switchDev};
    my $value=$hashHumDevice->{READINGS}{$humReading}{VAL};
    my $trend = addToList($value);
    Log3 $name, 4, "GetUpdate: trend=$trend";

    #TODO get onstatus
    my $onStatus = ReadingsVal($hash->{SwitchDevice}, "state", "na"); # $hashSwitchDevice->{READINGS}{state};

    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "trend", $trend, 1);
    readingsBulkUpdate($hash, "ValueList", join(", ", @ValueList), 1);
    readingsBulkUpdate($hash, "state", $onStatus, 1);
    readingsEndUpdate($hash, 1);
=pod    
    #update trend
    readingsSingleUpdate($hash, "trend", $trend, 1);
    #update Reading
    my $rv = readingsSingleUpdate($hash, "ValueList", join(", ", @ValueList), 1);
    #update Reading
    $rv = readingsSingleUpdate($hash, "state", $onStatus, 1);
    #update STATE
    $hash->{STATE}=$onStatus;
    Log3 $name, 4, "BadLuefter_GetUpdate: onStatus $onStatus ...";
=cut
    
    if($trend >0){
        #set-on-for-timer...
        my $onTest = fhem ( '{ ReadingsVal("schalterbadfeuchte2", "state", "na") } ');
        Log3 $name, 4, "ReadingsVal $switchDev ist $onTest ########";
        
        if($onTest eq "off"){
            
            Log3 $name, 4, "BadLuefter_GetUpdate: switch on-for-tmer $switchDev ...##########";
            my $res = fhem("set $switchDev on-for-timer 300"); # 5 minuten
            Log3 $name,4 ,"fhem set on-for-timer result=$res #########";
            
            #TODO: update state
            Log3 $name, 4, "BadLuefter_GetUpdate: set state to on...";
            readingsSingleUpdate($hash, "state", "on", 1);
##            fhem("setreading $name state on");
            
            #set internal STATE
##            $hash->{STATE} = "on";
            readingsSingleUpdate($hash, "state", "on", 1);
            
            @ValueList=(); #reset value list
        }
        else{
            Log3 $name, 4, "BadLuefter_GetUpdate: $switchDev is ON...";
        }

    }else{
        Log3 $name, 4, "GetUpdate trend<=0";
    }
	#...
	
	# neuen Timer starten in einem konfigurierten Interval.
    RemoveInternalTimer( $hash );
##    InternalTimer( gettimeofday() + $hash->{Interval}, "BadLuefter_GetUpdate", $hash );
    InternalTimer( gettimeofday() + getInterval($hash), "BadLuefter_GetUpdate", $hash );
}

sub BadLuefter_Undef {
    my ($hash, $arg) = @_; 
    RemoveInternalTimer( $hash );

    return ;
}

sub BadLuefter_Get {
    my ($hash, @param) = @_;
=pod
    "HumidityDevice"    => "",
    "HumidityReading"    => "",
    "SwitchDevice"  => "",
    "Interval"  => 60,
    "ValList" => ""
{Dumper $defs{badluefter} }
$VAR1 = {
          'STATE' => '???',
          'SwitchDevice' => 'schalterbadfeuchte2',
          'DEF' => 'HM_633ADB_Climate humidity schalterbadfeuchte2',
          'Interval' => 60,
          'TYPE' => 'BadLuefter',
          'NR' => 107,
          'NTFY_ORDER' => '50-badluefter',
          'FUUID' => '6b042703-f33f-77f3-e3ec-892a0623886ea94b',
          'HumidityDevice' => 'HM_633ADB_Climate',
          'NAME' => 'badluefter',
          'HumidityReading' => 'humidity'
        };
        
for attributes use: 
AttrVal(<devicename>,<attribute>,<defaultvalue>)
Returns the attribute of a device 

=cut    
    return '"get BadLuefter" needs at least one argument' if (int(@param) < 2);
    
    my $name = shift @param;
    my $opt = shift @param;
    my $value = shift @param;# InternalVal($name, $opt, "");
    Log3 $name, 4, "hash=$hash, name=$name, opt=$opt, value: " . $value;
    # 2026.11.23 19:06:32 4: hash=HASH(0x562b6f394a38), name=badluefter, opt=HumidityDevice, Setting: HM_633ADB_Climate

    return "\"get $name\" needs at least one argument" unless(defined($opt));

    Log3 $name, 4, "_Get: name=$name, opt=$opt, return=$defs{$name}->{$opt}";
    
    return "Unknown argument $opt, choose one of ".
    join ' ', sort values %BadLuefter_gets if !exists $BadLuefter_gets{$opt};

    if($opt eq "ValueList"){
        my $list=join(", ", @ValueList);
        return "ValueList: $list";
    }
    return $defs{$name}->{$opt};
}

sub BadLuefter_Set($@)
{
=pod
    "HumidityDevice"    => "",
    "HumidityReading"    => "",
    "SwitchDevice"  => "",
    "Interval"  => 60,
    "ValList" => ""
=cut    
	my ( $hash, $name, $cmd, @args ) = @_;
	return "\"set $name\" needs at least one argument" unless(defined($cmd));
    my $onStatus = ReadingsVal($hash->{SwitchDevice}, "state", "na"); # $hashSwitchDevice->{READINGS}{state};
    Log3 $name, 4, "onStatus=$onStatus";
    
    if($cmd eq "Interval")
    {
        if($args[0] eq $args[0]+0){
##            $hash->{Interval}=$args[0];
##            fhem ("attr $name Interval $args[0]");
            setInterval($hash, $args[0]);
            RemoveInternalTimer( $hash );
##            InternalTimer( gettimeofday() + $hash->{Interval}, "BadLuefter_GetUpdate", $hash );
            InternalTimer( gettimeofday() + getInterval($hash), "BadLuefter_GetUpdate", $hash );
        }else{
            return "Invalid value $args[0] for $cmd, choose a valid number of seconds.";
        }
    }
	elsif($cmd eq "HumidityDevice")
	{
	   if(! $args[0] eq "")
	   {
           my $test = $defs{$args[0]};
           if(defined($test)){
               $hash->{HumidityDevice}=$args[0];
           }else{
               return "device $args[0] is not defined";
           }
	   }
	   else
	   {
	      return "Invalid value $args[0] for $cmd, choose existing device";
	   }       
	}
    elsif ($cmd eq "HumidityReading"){
	   if(! $args[0] eq "")
	   {
           $hash->{HumidityReading}=$args[0];   
       }
    }elsif ( $cmd eq "SwitchDevice" ){
       my $test = $defs{$args[0]};
       if(defined($test)){
           $hash->{SwitchDevice}=$args[0];
       }else{
           return "device $args[0] is not defined";
       }
    }
    elsif ($cmd eq "ValueList"){
        return "ValueList can not be set directly";
    }
	else
	{
		return "Unknown argument $cmd, choose one of HumidityDevice HumidityReading SwitchDevice "; ##Interval is in Attributes
	}
}

# Prüfung von Attribut Werten beim Setzen
sub BadLuefter_Attr ($$$$) {
    my ($cmd,$name,$attr_name,$attr_value) = @_;
    Log3 $name, 4, "BadLuefter_Attr called...cmd=$cmd, name=$name, attr_name=$attr_name, attr_value=$attr_value";
    # $cmd  - Vorgangsart - kann die Werte "del" (löschen) oder "set" (setzen) annehmen
    # $name - Gerätename
    # $aName/$aValue sind Attribut-Name und Attribut-Wert

    my $hash = $defs{$name};
#    Log3 $name, 4, "BadLuefter_Attr: attr liste =". $hash->{AttrList};

    if($cmd eq "set") {
        if( index("Interval on_time verbose" . $readingFnAttributes, $attr_name) ){
            if($attr_name eq "Interval"){
                if($attr_value eq $attr_value+0){ #is number?
##                   $hash->{Interval}=$attr_value;
                   setInterval($hash, $attr_value);    
                }else{
                    my $err = "Invalid argument $attr_value to $attr_name. Must be a number (seconds).";
                    Log3 $name, 4, "BadLuefter: ".$err;
                    return $err;
                }
            }
            else {
                return; # default attributes?
                #return "BadLuefter_Attr: Unknown attr $attr_name";
            }
        }
        else{
            Log3 $name, 4, "BadLuefter_Attr: attribute not in list: $attr_name";
        }
    }
    return;
}

sub BadLuefter_Notify($$)
{
  my ($own_hash, $dev_hash) = @_;
  my $ownName = $own_hash->{NAME}; # own name / hash

  return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled

  my $devName = $dev_hash->{NAME}; # Device that created the events

  my $events = deviceEvents($dev_hash,1);
  return if( !$events );

  foreach my $event (@{$events}) {
    $event = "" if(!defined($event));

    # Examples:
    # $event = "readingname: value" 
    # or
    # $event = "INITIALIZED" (for $devName equal "global")
    #
    # processing $event with further code

    if( ($devName eq "global") && ($event eq "INITIALIZED") ){
        Log3 $ownName, 4, "BadLuefter_Notify called for global:INITIALIZED";
##        InternalTimer( gettimeofday() + $own_hash->{Interval}, "BadLuefter_GetUpdate", $own_hash );
        InternalTimer( gettimeofday() + getInterval($own_hash) , "BadLuefter_GetUpdate", $own_hash );
    }
  }
}

sub BadLuefter_State($$$$)
{
	my ( $hash, $time, $readingName, $value ) = @_;

    my $hashSwitchDevice = $hash->{SwitchDevice};
    my $switchState = $hashSwitchDevice->{READINGS}{state};
    readingsSingleUpdate($hash, "state", $switchState, 1);
    
	return undef if($readingName eq "STATE" || $value ne "inactive");
	my $rv = readingsSingleUpdate($hash, "state", "inactive", 1);
	return undef;
}

1;

=pod

use an array to manage up to 9 values
my @values;
push @values, $new; # adds new element at end
my $first = shift @values; # returns firts element and removes it from array
my $count = @values; # get number of elements, or use 
#my $count = scalar(@values);
#iterate thru values
foreach $element (@values) {
    print $element;
}
#get element by index
my $element = $values[0];

=begin html

<a name="BadLuefter"></a>
<h3>BadLuefter</h3>
<ul>
    <i>BadLuefter</i> implements the classical "BadLuefter World" as a starting point for module development. 
    You may want to copy 98_BadLuefter.pm to start implementing a module of your very own. See 
    <a href="http://wiki.fhem.de/wiki/DevelopmentModuleIntro">DevelopmentModuleIntro</a> for an 
    in-depth instruction to your first module.
    <br><br>
    <a name="BadLuefterdefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; BadLuefter &lt;greet&gt;</code>
        <br><br>
        Example: <code>define HELLO BadLuefter TurnUrRadioOn</code>
        <br><br>
        The "greet" parameter has no further meaning, it just demonstrates
        how to set a so called "Internal" value. See <a href="http://fhem.de/commandref.html#define">commandref#define</a> 
        for more info about the define command.
    </ul>
    <br>
    
    <a name="BadLuefterset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
        <br><br>
        You can <i>set</i> any value to any of the following options. They're just there to 
        <i>get</i> them. See <a href="http://fhem.de/commandref.html#set">commandref#set</a> 
        for more info about the set command.
        <br><br>
        Options:
        <ul>
              <li><i>satisfaction</i><br>
                  Defaults to "no"</li>
              <li><i>whatyouwant</i><br>
                  Defaults to "can't"</li>
              <li><i>whatyouneed</i><br>
                  Defaults to "try sometimes"</li>
        </ul>
    </ul>
    <br>

    <a name="BadLuefterget"></a>
    <b>Get</b><br>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        You can <i>get</i> the value of any of the options described in 
        <a href="#BadLuefterset">paragraph "Set" above</a>. See 
        <a href="http://fhem.de/commandref.html#get">commandref#get</a> for more info about 
        the get command.
    </ul>
    <br>
    
    <a name="BadLuefterattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> for more info about 
        the attr command.
        <br><br>
        Attributes:
        <ul>
            <li><i>formal</i> no|yes<br>
                When you set formal to "yes", all output of <i>get</i> will be in a
                more formal language. Default is "no".
            </li>
        </ul>
    </ul>
</ul>

=end html

=cut
