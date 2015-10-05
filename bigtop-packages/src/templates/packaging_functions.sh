# Looks up which subdirectory of /usr/lib or ${PARCELS_ROOT}/CDH/lib a JAR is owned by
# Outputs nothing if a symlink should not be made or the directory is unknown
# strip_versions <basename of JAR>
get_directory_for_jar() {
    case ${1} in
        avro*cassandra*) return;; # This is not included in our Avro distribution, but Mahout used to use it
        hadoop-client*) return;;
        hbase-client*-tests.jar) return;;
        trevni*) lib_dir='avro';;
        zookeeper*) lib_dir='zookeeper-client';;
        hadoop-aws*) lib_dir='hadoop-client';;
        hadoop-yarn*) lib_dir='hadoop-yarn-client';;
        hadoop-hdfs*) lib_dir='hadoop-hdfs-client';;
        hadoop-archives*) lib_dir='hadoop-mapreduce-client';;
        hadoop-distcp*) lib_dir='hadoop-mapreduce-client';;
        hadoop-mapreduce*) lib_dir='hadoop-mapreduce-client';;
        hadoop-ant*) lib_dir='hadoop-0.20-mapreduce';;
        hadoop-core*) lib_dir='hadoop-0.20-mapreduce';;
        hadoop-tools*) lib_dir='hadoop-0.20-mapreduce';;
        hadoop-streaming*-mr1*) lib_dir='hadoop-0.20-mapreduce/contrib/streaming';;
        hadoop-streaming*) lib_dir='hadoop-mapreduce-client';;
        hadoop*) lib_dir='hadoop-client';;
        hbase-indexer*) lib_dir='hbase-solr/lib';;
        hbase-sep*) lib_dir='hbase-solr/lib';;
        hbase*) lib_dir='hbase-client/lib';;
        hive-hcatalog*) lib_dir='hive-hcatalog/share/hcatalog';;
        hive-webhcat-java-client*) lib_dir='hive-hcatalog/share/webhcat/java-client';;
        hive*) lib_dir='hive-client/lib';;
        solr*) lib_dir='solr';;
        lucene*) lib_dir='solr/webapps/solr/WEB-INF/lib';;
        kite*) lib_dir='kite';;
        crunch*) lib_dir='crunch';;
        search-crunch*) lib_dir='solr/contrib/crunch';;
        search-mr*) lib_dir='solr/contrib/mr';;
        search*) lib_dir='search/lib';;
        pig*) lib_dir='pig';;
        spark-examples*) lib_dir='spark/lib';;
        spark-assembly*) lib_dir='spark/lib';;
        # Sqoop and Sqoop 2 JARs will look very similar
        sqoop*-1.4*) lib_dir='sqoop';;
        sqoop*-1.99*) lib_dir='sqoop2/client-lib';;
        *) return;;
    esac
    echo "/usr/hdp/current/${lib_dir}"
}

# Looks up which package can be depended on to install a certain directory, to map symlinks to package dependencies
function check_for_package_dependency() {
    case ${1} in
        /usr/hdp/current/zookeeper-client) pkg=zookeeper;;
        /usr/hdp/current/hadoop-yarn-client) pkg=hadoop-yarn;;
        /usr/hdp/current/hadoop-hdfs-client) pkg=hadoop-hdfs;;
        /usr/lib/hadoop-0.20-mapreduce) pkg=hadoop-0.20-mapreduce;;
        /usr/hdp/current/hadoop-mapreduce-client) pkg=hadoop-mapreduce;;
        /usr/hdp/current/hadoop-client*) pkg=hadoop-client;;
        /usr/hdp/current/hadoop-client) pkg=hadoop;;
        /usr/lib/hbase-solr/lib) pkg=hbase-solr;;
        /usr/hdp/current/hbase-client) pkg=hbase;;
        /usr/lib/hive-hcatalog/share/hcatalog) pkg=hcatalog;;
        /usr/lib/hive-hcatalog/share/webhcat/java-client) pkg=hive-webhcat;;
        /usr/hdp/current/hive-client/lib) pkg=hive;;
        /usr/lib/solr/contrib/crunch) pkg=solr-crunch;;
        /usr/lib/solr/contrib/mr) pkg=solr-mapreduce;;
        /usr/lib/solr*) pkg=solr;;
        /usr/lib/kite) pkg=kite;;
        /usr/lib/crunch) pkg=crunch;;
        /usr/lib/search/lib) pkg=search;;
        /usr/lib/pig) pkg=pig;;
        /usr/lib/sqoop) pkg=sqoop;;
        /usr/lib/sqoop2*) pkg=sqoop2;;
        /usr/lib/spark*) pkg=spark;;
        *) return;;
    esac

    metadata_files=$(find ../.. -name *.spec -o -name control)
    if ! cat ${metadata_files} | grep "^\(Depends\|Requires\).*\\b${pkg}\\b" > /dev/null; then
        echo "[SYMLINKING WARNING] Package may have broken symlink to ${pkg}"
    fi
}

# Strips all versioning info from a JAR file name (e.g. avro-1.7.5-cdh5.0.0-SNAPSHOT-hadoop2.jar -> avro-hadoop2.jar)
# This function is known to behave incorrectly when using BSD versions of sed and grep instead of GNU
# strip_versions <file name>
function strip_versions() {
    original="${1}"
    if echo "${original}" | grep 'hive-shims-0.23' > /dev/null; then
        # 0.23 is significant (i.e. hive-shims-0.23 and hive-shims must be distinct)
        # This cannot be generalized as being different from similar expressions
        hive_shims_mr1_exception='true'
    else
        hive_shims_mr1_exception='false'
    fi
    modified="${original}"
    # First we remove easy stuff like -SNAPSHOT and -beta-*
    modified=`echo ${modified} | sed -e 's/-SNAPSHOT//g'`
    modified=`echo ${modified} | sed -e 's/-beta-[0-9]\+//g'`
    # Next we remove all CDH versions and similar "profile" versions
    modified=`echo ${modified} | sed -e 's/-\(cdh\|hbase\|hadoop\)[0-9]\.[0-9.]\+\?[0-9]//g'`
    # Compound versions (e.g. in Oozie) confuse things (has happened in Spark too)
    modified=`echo ${modified} | sed -e 's/\.oozie//g'`
    # Penultimately, remove all component versions and timestamps - this may remove trailing hyphens that previous expressions rely on
    modified=`echo ${modified} | sed -e 's/\(-\|_\)[0-9]\+\.[-0-9\.]\+\?[0-9]//g'`
    # Finally, make sure the filename ends with '.jar' - previous expressions have to risk remove the period
    modified=`echo ${modified} | sed -e 's/\([^.]\)jar$/\1.jar/'`
    if "${hive_shims_mr1_exception}" == 'true'; then
        modified="${modified/hive-shims/hive-shims-0.23}"
    fi
    echo "${modified}"
}

# Creates versionless symlinks to JARs in the same directory (e.g. /usr/lib/zookeeper/zookeeper.jar -> /usr/lib/zookeeper/zookeeper-3.4.5-cdh5.0.0-SNAPSHOT.jar)
# internal_versionless_symlinks <JAR files to link>
function internal_versionless_symlinks() {
    for file in ${@}; do
        pushd `dirname ${file}`
        base_jar=`basename ${file}`
        #Do the following in a subshell so that we do not
        #mess up shell options in current shell
        test_base_jar=` shopt -s nullglob ; echo $base_jar`
        if [ -z "$test_base_jar" ] ; then
            echo "'$base_jar' seems like an invalid link" >&2
            exit 1
        fi
            
        #Do not need to make sure that base_jar does not have multiple 
        #components since that will lead to the next ln failing
        new_name=`strip_versions ${base_jar}`
        ln -s ${base_jar} "$new_name"
        #Adding diagnostic message to help testing changes
        echo "internal_versionless_symlink_createlink:linkname=${new_name}:linktarget=${base_jar}"
        popd
    done
}

# Creates symlinks between one component and another, dependent component (e.g. /usr/lib/hadoop/avro.jar -> /usr/lib/avro/avro.jar)
# Assumes that internal versionless symlinks already exist in the dependency
# external_versionless_symlinks <prefix (or quoted list of prefixed) to exclude> <directories to scan for JARs>
function external_versionless_symlinks() {
    predicate=''
    skip=${1}; shift 1;
    # Find all files we might want to symlink (it's okay if this returns a superset of what we actually want to symlink)
    for prefix in crunch zookeeper hive hadoop hbase search solr lucene kite trevni sqoop spark pig; do
        if [ -n "${predicate}" ]; then predicate="${predicate} -o "; fi
        predicate="${predicate} -name ${prefix}*.jar";
    done
    for dir in $@; do
        for old_jar in `find $dir -maxdepth 1 ${predicate}`; do
            base_jar=`basename $old_jar`;
            for prefix in ${skip}; do
                # Leave JARs from the specified component alone (parquet format is an exception in parquet)
                if [[ "${base_jar}" =~ ^${prefix} ]]; then continue 2; fi
            done
            new_jar=`strip_versions $base_jar`
            # dir must be looked up using the versioned JAR!
            new_dir=`get_directory_for_jar ${base_jar}`
            if [ -z "${new_dir}" ]; then continue; fi
            check_for_package_dependency ${new_dir}
            rm $old_jar && ln -fs ${new_dir}/${new_jar} $dir/
            #Adding diagnostic message to help testing changes
            echo "external_versionless_symlink_replacement:oldjar=$old_jar:newjar=${new_jar}"
        done
    done
}

