#!/usr/bin/env bash

: "
  Copyright (C) 2011-:
        Vinay Makam, www.linkedin.com/in/vinaymakam

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the 
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
  sell copies of the Software, and to permit persons to whom the Software is 
  to do so, subject to the following conditions:
                   
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
                          
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
  DEALINGS IN THE SOFTWARE.
" 
#--Please choose appropriate hadoop and spark links for your installation.

bash_file="$HOME/.bashrc"
install_path="/usr/local"

hadoop_url=http://apache.osuosl.org/hadoop/common/hadoop-2.7.4/hadoop-2.7.4.tar.gz 
hadoop_file=hadoop-2.7.4.tar.gz 
hadoop_folder_name=hadoop-2.7.4
hadoop_xml_folder=$install_path/$hadoop_folder_name/etc/hadoop   

spark_url=http://apache.mirrors.tds.net/spark/spark-2.1.1/spark-2.1.1-bin-hadoop2.7.tgz
spark_file=spark-2.1.1-bin-hadoop2.7.tgz
spark_folder_name=spark-2.1.1-bin-hadoop2.7

user_name="hduser"
group_name="hadoop"

install_flag=0

clear

echo ""; echo ""; echo ""
echo "This script will install Hadoop and Spark to your local directory, modify 
your PATH,and add environment variables to your SHELL config file"
read -r -p "Proceed? [y/N] " response
if [[ ! $response =~ ^([yY][eE][sS]|[yY])$ ]]
then
    echo "Aborting..."
    sleep 1
    exit 1
fi

#--Packages currently installed with new versions available are retrieved 
#--and upgraded; under no circumstances are currently installed packages 
#--removed, nor are packages that are not already installed retrieved 
#--and installed.
#sudo apt-get update && sudo apt-get upgrade 
#sudo apt-get -y install software-properties-common
#sudo apt-get -y install vim

clear 

#--Add a new hadoop group "hadoop" 
getent group $group_name 2> /dev/null
if [ ! $? -eq 0 ]; then 
    echo "Creating a group 'hadoop' "
    sudo addgroup hadoop
fi 

#--Add a new user "hduser" 
getent passwd $user_name 2> /dev/null
if [ ! $? -eq 0 ]; then 
    echo "Creating a user 'hduser' "
    sudo adduser --ingroup hadoop hduser
    sudo adduser hduser sudo
fi

#--Check SSH installation/configuration.
ssh -V 2> /dev/null
if [ ! $? -eq 0 ]; then 
    echo "Installing SSH"
    sudo apt-get -y install ssh
    sudo apt-get -y install rsync
    ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
    cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys
fi

#--Check JAVA is installed.
javac -version 2> /dev/null
if [ ! $? -eq 0 ]; then  
    echo "Installing Java"
    apt-get install -y software-properties-common python-software-properties
    sudo add-apt-repository -y ppa:webupd8team/java
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
    sudo apt-get install oracle-java8-installer
    sudo apt-get -y update 
fi

#--Check HADOOP is installed.
hadoop version 2> /dev/null
if [ ! $? -eq 0 ]; then 
    echo "Installing Hadoop" 
    wget $hadoop_url 
    sudo tar zxvf $hadoop_file -C $install_path 
    sudo chown -R $user_name:$group_name $HADOOP_HOME
    install_flag=1
    sudo rm -rf $hadoop_file 
    sleep 1
fi

#--Bashrc and XML file configurations.
_hadoop_config () {

echo " 
export JAVA_HOME=/usr/lib/jvm/java-8-oracle
export HADOOP_INSTALL=$install_path/$hadoop_folder_name 
export HADOOP_HOME=$install_path/$hadoop_folder_name 
export PATH=\$PATH:\$HADOOP_INSTALL/bin:\$HADOOP_INSTALL/sbin
export HADOOP_MAPRED_HOME=\$HADOOP_INSTALL
export HADOOP_COMMON_HOME=\$HADOOP_INSTALL
export HADOOP_HDFS_HOME=\$HADOOP_INSTALL
export YARN_HOME=\$HADOOP_INSTALL
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_INSTALL/lib/native
export HADOOP_OPTS="-Djava.library.path=\$HADOOP_INSTALL/lib/native"
export HADOOP_CONF_DIR=\$HADOOP_INSTALL/etc/hadoop" >> $bash_file 

source $bash_file    

#--Snappy compression configuration For HADOOP  
sudo apt-get install -y libsnappy-dev
sudo cp /usr/lib/x86_64-linux-gnu/lib* $HADOOP_HOME/lib/native/

#--Update JAVA path to hadoop-env.sh 
sudo sed -i 's/\${JAVA_HOME}/\/usr\/lib\/jvm\/java-8-oracle/g' $hadoop_xml_folder/hadoop-env.sh

#--Modify core-site.xml 
sudo sed -i -r '/FOOTER/d; s/(<configuration>)//; 
                           s/(<\/configuration>)//' $hadoop_xml_folder/core-site.xml 
sudo echo "
<configuration>
   <property>
      <name>fs.default.name</name>
      <value>hdfs://localhost:9000</value> 
   </property>
</configuration> "  >> $hadoop_xml_folder/core-site.xml 

#--Modify yarn-site.xml 
sudo sed -i -r '/FOOTER/d; s/(<configuration>)//;  
                           s/(<\/configuration>)//' $hadoop_xml_folder/yarn-site.xml 
sudo echo "
<configuration>
   <property>
      <name>yarn.nodemanager.aux-services</name>
      <value>mapreduce_shuffle</value>
   </property>
</configuration> " >> $hadoop_xml_folder/yarn-site.xml

#--Modify hdfs-site.xml 
sudo sed -i -r '/FOOTER/d; s/(<configuration>)//;   
                           s/(<\/configuration>)//' $hadoop_xml_folder/hdfs-site.xml 
sudo echo "
<configuration>
   <property>
      <name>dfs.replication</name>
      <value>1</value>
   </property>
   <property>
      <name>dfs.name.dir</name>
      <value>/hdfs_storage/name</value>
   </property>
   <property>
      <name>dfs.data.dir</name> 
      <value>/hdfs_storage/data</value> 
   </property>
</configuration> " >> $hadoop_xml_folder/hdfs-site.xml 

#--Modify mapred-site.xml 
if [-f $hadoop_xml_folder/mapred-site.xml ]; then 
    sudo sed -i -r '/FOOTER/d; s/(<configuration>)//;  
                   s/(<\/configuration>)//' $hadoop_xml_folder/mapred-site.xml
else
    sudo cp $hadoop_xml_folder/mapred-site.xml.template $hadoop_xml_folder/mapred-site.xml 
    sudo sed -i -r '/FOOTER/d; s/(<configuration>)//;  
                   s/(<\/configuration>)//' $hadoop_xml_folder/mapred-site.xml
    sudo chown -R $user_name:$group_name $hadoop_xml_folder/mapred-site.xml 
fi 

sudo echo "
<configuration>
   <property>
      <name>mapred.job.tracker</name>
      <value>localhost:54311</value>        
      <description>The host and port that the MapReduce job tracker runs
                    at. If "local", then jobs are run in-process as a single map
                    and reduce task.
      </description>
   </property>
   <property> 
      <name>mapreduce.framework.name</name>
      <value>yarn</value>
   </property>
</configuration> " >> $hadoop_xml_folder/mapred-site.xml
}

#--HADOOP configurations:
#-- bashrc file updates
#-- Snappy compression configuration
#-- XML configurations
if [ $install_flag -eq 1 ]; then 
    #--Pseudo Hadoop configurations.
    _hadoop_config 

    echo "creating required hdfs directories"
    sudo mkdir -p /hdfs_storage/data
    sudo mkdir -p /hdfs_storage/name
    sudo chown -R $user_name:$group_name /hdfs_storage

    echo "creating log directory"
    sudo mkdir -p $HADOOP_HOME/logs
    sudo chown -R $user_name:$group_name $HADOOP_HOME/logs

    #--Format the HDFS
    hdfs namenode -format

    echo "Hadoop installation and setup is complete."
fi 

#--Spark configurations.
_spark_config () {

echo "
#--Spark 
export SPARK_HOME=$install_path/$spark_folder_name
export PYTHONPATH=$install_path/$spark_folder_name/python/:$PYTHONPATH 
export PYSPARK_PYTHON=/usr/bin/python3
export PYSPARK_DRIVER_PYTHON=/usr/bin/python3
export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin"  >> $bash_file 

source $bash_file

sudo cp $SPARK_HOME/conf/spark-env.sh.template $SPARK_HOME/conf/spark-env.sh 
sudo chown -R $user_name:$group_name $SPARK_HOME/conf/spark-env.sh 
sudo cp $SPARK_HOME/conf/log4j.properties.template $SPARK_HOME/conf/log4j.properties 
sudo chown -R $user_name:$group_name $SPARK_HOME/conf/log4j.properties

sudo echo "
#--Spark-setup 
export PYTHONPATH=$install_path/$spark_folder_name/python/:$PYTHONPATH 
export PYSPARK_PYTHON=/usr/bin/python3
export PYSPARK_DRIVER_PYTHON=/usr/bin/python3" >> $SPARK_HOME/conf/spark-env.sh

}

#--Check SPARK is installed.
spark-submit --version 2> /dev/null
if [ ! $? -eq 0 ]; then 
    echo "Installing Spark and prerequisites" 
    sudo pip install py4j 
    wget $spark_url 
    sudo tar -xzf $spark_file -C $install_path   
    sudo chown -R $user_name:$group_name $SPARK_HOME/ 
    sudo rm -rf $spark_file 
    _spark_config 
fi

echo "Installation completed successfully."
