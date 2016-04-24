FROM ruby:2.3
MAINTAINER emdentec ltd. <docker@emdentec.com>

ENV WORK_DIR /usr/lib/janky

RUN mkdir -p $WORK_DIR

COPY Gemfile $WORK_DIR/Gemfile
RUN cd $WORK_DIR && bundle install

COPY . $WORK_DIR

WORKDIR $WORK_DIR
EXPOSE 80

CMD ["bundle", "exec", "thin", "start", "-p", "80"]
