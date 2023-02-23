#!/bin/bash
# 注:当需要多学期学期时，建议多脚本并行执行以加快刷视频的速度,如 ./video.sh 1(表示刷第一学期的视频)

# 指定学习第几个学期,支持从命令行的参数去设置
# 注:1表示$1,5表示第5学期,当$1不存在时target_study_year=5,$1存在时使用target_study_year=$1
target_study_year=${1:-5}

# 指定Cookie
# 格式:header_cookie="Cookie: sessionId=48K50np1t2zoIp8etn1Md8u1Wn4A7f4l; UserKey=77E8sgV2ZhdE587Vxs0NQ6K87cAP06hj"
header_cookie="Cookie: "

# 当一次循环保存记录后,如果进度依然是0，需要更换IP
# 自动指定
ip=$(curl -s cip.cc | grep "[[:digit:]].*" -o | head -n 1)
# 手动指定（2022-11-24 仅需要设定新的ip变量即可，无需保证真实的出口IP）
# ip="xxx.xxx.xxx.xxx"

# 以下变量不需要变化
header_accept="Accept: */*'"
header_accept_language="Accept-Language: zh-CN,zh;q=0.9"
header_access_control_allow_origin="Access-Control-Allow-Origin: *"
header_cache_control="Cache-Control: max-age=0"
header_connection="Connection: keep-alive"
header_content_type="Content-Type: application/json; charset=utf-8"
header_user_agent="User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"

echo "当代年轻人学习网课方式! IP:${ip}"

function log() {
    echo -e "$(date "+%F %T") ${1}"
}
function error() {
    echo -e "\033[1;31m$(date "+%F %T") ${1}\033[0m"
}
function CommandLineOnlineClasses() {
    curl_save_course_look=$(curl -s "http://jjxy.web2.superchutou.com/service/datastore/WebCourse/SaveCourse_Look" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --data "{\"CourseChapters_ID\":\"${1}\",\"LookType\":0,\"LookTime\":60,\"IP\":\"${ip}\"}" --compressed --insecure | jq -r '.Message')

    case "$curl_save_course_look" in
    *观看记录添加成功*)
        log "${curl_save_course_look} ${3} ${2} 进度:${4}"
        ;;
    *)
        error "${curl_save_course_look} ${3} ${2} 进度:${4}"
        ;;
    esac
}
function GetCourseChapterList() {

    curl_list=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Question/GetCourse_ChaptersNodeList?Valid=1&Course_ID=${1}&StuID=${StuID}&Curriculum_ID=${2}&Examination_ID=${3}&StuDetail_ID=${StuDetail_ID}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    chapter_list_length=$(echo "$curl_list" | jq '.Data|length')
    log "共${chapter_list_length}章"

    for ((j = 0; j < chapter_list_length; j++)); do
        chapter_name=$(echo "$curl_list" | jq ".Data[$j].Name")
        chapter_child_length=$(echo "$curl_list" | jq ".Data[$j].ChildNodeList | length")
        log "检查 $chapter_name,包含${chapter_child_length}节小课"

        for ((k = 0; k < chapter_child_length; k++)); do
            chapter_child_name=$(echo "$curl_list" | jq ".Data[$j].ChildNodeList[$k].CourseWare_Name")
            chapter_child_islook=$(echo "$curl_list" | jq ".Data[$j].ChildNodeList[$k].IsLook")
            chapter_child_totalsecond=$(echo "$curl_list" | jq ".Data[$j].ChildNodeList[$k].TotalSecond")

            if [ "$chapter_child_islook" == "0" ]; then
                CommandLineOnlineClasses "$(echo "$curl_list" | jq ".Data[$j].ChildNodeList[$k].ID")" "$chapter_child_name" "${chapter_name}" "$chapter_child_totalsecond"
                is_look_status=$((is_look_status + 1))
            else
                log "已完成 ${chapter_child_name} "
            fi
        done
    done

}
function init() {
    os=$(uname)
    case $os in
    # macOS基本命令检测
    Darwin)
        which curl >/dev/null 2>&1 || {
            log "准备安装curl命令,具体命令"
            brew install curl || {
                error "brew install curl 执行失败"
                exit 1
            }
        }
        which jq >/dev/null 2>&1 || {
            log "准备安装jq命令..."
            brew install jq || {
                error "brew install jq 执行失败"
                exit 1
            }
        }
        return
        ;;
    Linux)
        # Centos 基本命令检测
        test -r /etc/redhat-release && grep "CentOS" /etc/redhat-release >/dev/null 2>&1 && {

            which curl >/dev/null 2>&1 || {
                log "准备安装curl命令"
                sudo yum -y install curl || {
                    error "sudo yum -y install curl 执行失败"
                    exit 1
                }
            }
            which jq >/dev/null 2>&1 || {
                log "准备安装jq命令..."
                sudo yum -y install jq || {
                    error "sudo yum -y install jq 执行失败"
                    exit 1
                }
            }
            return
        }
        # Ubuntu 基本命令检测
        lsb_release -a 2>/dev/null | grep "Ubuntu" >/dev/null 2>&1 && {
            which curl >/dev/null 2>&1 || {
                log "准备安装curl命令"
                sudo apt -y install curl || {
                    error "sudo apt -y install curl 执行失败"
                    exit 1
                }
            }
            which jq >/dev/null 2>&1 || {
                log "准备安装jq命令..."
                sudo apt -y install jq || {
                    error "sudo apt -y install jq 执行失败"
                    exit 1
                }
            }
            return
        }
        ;;

    esac
}

function main() {
    log "指定学习第${target_study_year}学期"

    # 获取学生ID
    curl_student_id=$(curl 'http://jjxy.web2.superchutou.com/service/eduSuper/StudentinfoDetail/GetStudentDetailRegisterSet' -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    StuDetail_ID=$(echo "$curl_student_id" | jq -r'.Data[0].StuDetail_ID')
    StuID=$(echo "$curl_student_id" | jq -r '.Data[0].StuID')

    test "$StuDetail_ID" = "null" && {
        echo "cookie无效"
        exit 1
    }

    # 获取课程列表
    curl_std_curriculum_list=$(curl "http://jjxy.web2.superchutou.com/service/eduSuper/Specialty/GetStuSpecialtyCurriculumList?StuDetail_ID=${StuDetail_ID}&IsStudyYear=1&StuID=${StuID}" -H "$header_accept" -H "$header_accept_language" -H "$header_access_control_allow_origin" -H "$header_cache_control" -H "$header_connection" -H "$header_content_type" -H "$header_cookie" -H "$header_user_agent" --compressed --insecure -s)
    study_year_total=$(echo "$curl_std_curriculum_list" | jq '.Data.list | length')
    study_year_max=$(echo "$curl_std_curriculum_list" | jq ".Data.list[$((study_year_total - 1))].StudyYear")

    test "$study_year_total" -eq 0 && {
        error "获取学期数失败"
        exit 1
    }
    log "共${study_year_total}门课,共${study_year_max}学期"
    test "$target_study_year" -gt "$study_year_max" && {
        error "target_study_year变量指定错误,超过最大学期数$study_year_total"
        exit 1
    }
    for (( ; ; )); do
        is_look_status=0
        start_timestamp=$(date +%s)
        for ((i = 0; i < study_year_total; i++)); do
            std_curriculum_list=$(echo "$curl_std_curriculum_list" | jq ".Data.list[$i]")
            curriculum_study_year=$(echo "$std_curriculum_list" | jq ".StudyYear")

            # 如果不是指定的学期
            test "$curriculum_study_year" -ne "$target_study_year" && continue

            curriculum_name=$(echo "$std_curriculum_list" | jq -r ".CuName")
            curriculum_chapters=$(echo "$std_curriculum_list" | jq ".CourseChapters")
            curriculum_read_chapters=$(echo "$std_curriculum_list" | jq ".CourseReadChapters")

            test "$curriculum_chapters" -eq "$curriculum_read_chapters" && {
                log "跳过学习 ${curriculum_name} 目标课程已完成"
                continue
            }

            # 如果目标课程没有课程目录
            test "$curriculum_chapters" -eq 0 && {
                log "跳过学习 ${curriculum_name} 目标课程数为0"
                continue
            }

            log "开始学习 第${curriculum_study_year}学期的${curriculum_name} 目标课程数:${curriculum_chapters}, 已完成数:${curriculum_read_chapters}"
            curriculum_course_id=$(echo "$std_curriculum_list" | jq ".Course_ID")
            curriculum_curriculum_id=$(echo "$std_curriculum_list" | jq ".Curriculum_ID")
            curriculum_examination_id=$(echo "$std_curriculum_list" | jq ".Examination_ID")
            GetCourseChapterList "$curriculum_course_id" "$curriculum_curriculum_id" "$curriculum_examination_id" "$curriculum_name"
        done

        test "$is_look_status" -eq 0 && {
            log "第${target_study_year}学期的所有课程完成"
            start_timestamp=0
            break
        }
        diff_timestamp=$(($(date +%s) - start_timestamp))
        if [[ $diff_timestamp -ge 60 ]]; then
            log "本次执行时间为${diff_timestamp}s,跳过缓冲"
        else
            log "本次执行时间:${diff_timestamp}s,开始缓冲,缓存时间:$((60-diff_timestamp))s"
            sleep "$((60-diff_timestamp))"
        fi
    done
}
init
main
